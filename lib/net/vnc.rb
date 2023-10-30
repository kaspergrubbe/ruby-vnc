require 'socket'
require 'yaml'
require 'net/vnc/version'

module Net
  #
  # The VNC class provides for simple rfb-protocol based control of
  # a VNC server. This can be used, eg, to automate applications.
  #
  # Sample usage:
  #
  #   # launch xclock on localhost. note that there is an xterm in the top-left
  #
  #   require 'net/vnc'
  #   Net::VNC.open 'localhost:0', :shared => true do |vnc|
  #     vnc.pointer_move 10, 10
  #     vnc.type 'xclock'
  #     vnc.key_press :return
  #   end
  #
  # = TODO
  #
  # * The server read loop seems a bit iffy. Not sure how best to do it.
  # * Should probably be changed to be more of a lower-level protocol wrapping thing, with the
  #   actual VNCClient sitting on top of that. all it should do is read/write the packets over
  #   the socket.
  #
  class VNC
    class PointerState
      attr_reader :x, :y, :button

      def initialize(vnc)
        @x = @y = @button = 0
        @vnc = vnc
      end

      # could have the same for x=, and y=
      def button=(button)
        @button = button
        refresh
      end

      def update(x, y, button = @button)
        @x = x
        @y = y
        @button = button
        refresh
      end

      def refresh
        packet = 0.chr * 6
        packet[0] = 5.chr
        packet[1] = button.chr
        packet[2, 2] = [x].pack 'n'
        packet[4, 2] = [y].pack 'n'
        @vnc.socket.write packet
      end
    end

    BASE_PORT = 5900
    CHALLENGE_SIZE = 16
    DEFAULT_OPTIONS = {
      shared: false,
      wait: 0.1,
      pix_fmt: :BGRA,
      encoding: :RAW
    }

    keys_file = File.dirname(__FILE__) + '/../../data/keys.yaml'
    KEY_MAP = YAML.load_file(keys_file).inject({}) { |h, (k, v)| h.update k.to_sym => v }
    def KEY_MAP.[](key)
      super or raise(ArgumentError, 'Invalid key name - %s' % key)
    end

    attr_reader :server, :display, :options, :socket, :pointer, :desktop_name

    def initialize(display = ':0', options = {})
      @server = 'localhost'
      if display =~ /^(.*)(:\d+)$/
        @server = Regexp.last_match(1)
        display = Regexp.last_match(2)
      end
      @display = display[1..-1].to_i
      @desktop_name = nil
      @options = DEFAULT_OPTIONS.merge options
      @clipboard = nil
      @fb = nil
      @pointer = PointerState.new self
      @mutex = Mutex.new
      connect
      @packet_reading_state = nil
      @packet_reading_thread = Thread.new { packet_reading_thread }
    end

    def self.open(display = ':0', options = {})
      vnc = new display, options
      if block_given?
        begin
          yield vnc
        ensure
          vnc.close
        end
      else
        vnc
      end
    end

    def port
      BASE_PORT + @display
    end

    def connect
      @socket = TCPSocket.open(server, port)
      raise 'invalid server response' unless socket.read(12) =~ /^RFB (\d{3}.\d{3})\n$/

      @server_version = Regexp.last_match(1)
      socket.write "RFB 003.003\n"
      data = socket.read(4)
      auth = data.to_s.unpack1('N')
      case auth
      when 0, nil
        raise 'connection failed'
      when 1
        # ok...
      when 2
        raise 'Unable to authenticate - DES no longer supported'
      else
        raise 'Unknown authentication scheme - %d' % auth
      end

      # ClientInitialisation
      socket.write((options[:shared] ? 1 : 0).chr)

      # ServerInitialisation
      @framebuffer_width  = socket.read(2).to_s.unpack1('n').to_i
      @framebuffer_height = socket.read(2).to_s.unpack1('n').to_i

      # TODO: parse this.
      _pixel_format = socket.read(16)

      # read the name in byte chunks of 20
      name_length = socket.read(4).to_s.unpack1('N')
      @desktop_name = [].tap do |it|
        while name_length > 0
          len = [20, name_length].min
          it << socket.read(len)
          name_length -= len
        end
      end.join

      _load_frame_buffer
    end

    # this types +text+ on the server
    def type(text, options = {})
      packet = 0.chr * 8
      packet[0] = 4.chr
      text.split(//).each do |char|
        packet[7] = char[0]
        packet[1] = 1.chr
        socket.write packet
        packet[1] = 0.chr
        socket.write packet
      end
      wait options
    end

    # this takes an array of keys, and successively holds each down then lifts them up in
    # reverse order.
    # FIXME: should wait. can't recurse in that case.
    def key_press(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      keys = args
      raise ArgumentError, 'Must have at least one key argument' if keys.empty?

      begin
        key_down keys.first
        if keys.length == 1
          yield if block_given?
        else
          key_press(*(keys[1..-1] + [options]))
        end
      ensure
        key_up keys.first
      end
    end

    def get_key_code(which)
      case which
      when String
        raise ArgumentError, 'can only get key_code of single character strings' if which.length != 1

        which[0].ord
      when Symbol
        KEY_MAP[which]
      when Integer
        which
      else
        raise ArgumentError, "unsupported key value: #{which.inspect}"
      end
    end
    private :get_key_code

    def key_down(which, options = {})
      packet = 0.chr * 8
      packet[0] = 4.chr
      key_code = get_key_code which
      packet[4, 4] = [key_code].pack('N')
      packet[1] = 1.chr
      socket.write packet
      wait options
    end

    def key_up(which, options = {})
      packet = 0.chr * 8
      packet[0] = 4.chr
      key_code = get_key_code which
      packet[4, 4] = [key_code].pack('N')
      packet[1] = 0.chr
      socket.write packet
      wait options
    end

    def pointer_move(x, y, options = {})
      # options[:relative]
      pointer.update x, y
      wait options
    end

    BUTTON_MAP = {
      left: 0
    }

    def button_press(button = :left, options = {})
      button_down button, options
      yield if block_given?
    ensure
      button_up button, options
    end

    def button_down(which = :left, options = {})
      button = BUTTON_MAP[which] || which
      raise ArgumentError, 'Invalid button - %p' % which unless (0..2).include?(button)

      pointer.button |= 1 << button
      wait options
    end

    def button_up(which = :left, options = {})
      button = BUTTON_MAP[which] || which
      raise ArgumentError, 'Invalid button - %p' % which unless (0..2).include?(button)

      pointer.button &= ~(1 << button)
      wait options
    end

    # take screenshot as PNG image
    # @param dest [String|IO|nil] destination file path, or IO-object, or nil
    # @return [String] PNG binary data as string when dest is null
    #         [true]   else case
    def take_screenshot(dest = nil)
      fb = _load_frame_buffer # on-demand loading
      fb.save_pixel_data_as_png dest
    end

    def wait(options = {})
      sleep options[:wait] || @options[:wait]
    end

    def close
      # destroy packet reading thread
      if @packet_reading_state == :loop
        @packet_reading_state = :stop
        while @packet_reading_state
          # do nothing
        end
      end
      socket.close
    end

    def reconnect
      60.times do
        if @packet_reading_state.nil?
          connect
          @packet_reading_thread = Thread.new { packet_reading_thread }
          return true
        end
        sleep 0.5
      end
      warn 'reconnect failed because packet reading state had not been stopped for 30 seconds.'
      false
    end

    def clipboard
      if block_given?
        @clipboard = nil
        yield
        60.times do
          clipboard = @mutex.synchronize { @clipboard }
          return clipboard if clipboard

          sleep 0.5
        end
        warn 'clipboard still empty after 30s'
        nil
      else
        @mutex.synchronize { @clipboard }
      end
    end

    def clipboard=(text)
      text = text.to_s.gsub(/\R/, "\n") # eol of ClientCutText's text is LF
      byte_size = text.to_s.bytes.size
      packet = 0.chr * (8 + byte_size)
      packet[0] = 6.chr # message-type: 6 (ClientCutText)
      packet[4, 4] = [byte_size].pack('N') # length
      packet[8, byte_size] = text
      socket.write(packet)
      @clipboard = text
    end

    private

    def read_packet(type)
      case type
      when 0 # ----------------------------------------------- FramebufferUpdate
        @fb.handle_response type if @fb
      when 1 # --------------------------------------------- SetColourMapEntries
        @fb.handle_response type if @fb
      when 2 # ------------------------------------------------------------ Bell
        nil  # not support
      when 3 # --------------------------------------------------- ServerCutText
        socket.read 3 # discard padding bytes
        len = socket.read(4).unpack1('N')
        @mutex.synchronize { @clipboard = socket.read len }
      else
        warn 'unhandled server packet type - %d' % type
      end
    end

    def packet_reading_thread
      @packet_reading_state = :loop
      loop do
        break if @packet_reading_state != :loop
        next unless IO.select [socket], nil, nil, 2

        type = socket.read(1)[0]
        read_packet type.ord
      rescue StandardError
        warn "exception in packet_reading_thread: #{$!.class}:#{$!}\n#{$!.backtrace}"
        break
      end
      @packet_reading_state = nil
    end

    def _load_frame_buffer
      unless @fb
        require 'net/rfb/frame_buffer'

        @fb = Net::RFB::FrameBuffer.new @socket, @framebuffer_width, @framebuffer_height, @options[:pix_fmt],
                                        @options[:encoding]
        @fb.send_initial_data
      end
      @fb
    end
  end
end
