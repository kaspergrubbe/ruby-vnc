require 'thread'
require_relative 'enchex'
require_relative 'encraw'
require_relative 'enczrle'
require_relative 'constants'

module Net::RFB

  # Manage FrameBuffer pixel data for RFB protocol
  # Diverted from vncrec-ruby https://github.com/d-theus/vncrec-ruby
  class FrameBuffer
    attr_accessor :name, :w, :h, :io, :data

    # @param io [IO, #read, #sysread, #syswrite, #read_nonblock] string stream from VNC server.
    # @param w width of the screen area
    # @param h height of the screen area
    # @param bpp bits per pixel
    def initialize(io, w, h, bpp)
      @io = io
      @w = w
      @h = h
      @bpp = bpp
      @bypp = (bpp / 8.0).to_i
      @wb = @w * @bypp
      @data = "\x00" * @wb * @h

      @cb_mutex = Monitor.new
      @cb_cv = @cb_mutex.new_cond
    end

    # Set a way that server should use to represent pixel data
    # @param [Hash] pixel format:
    #  * {Net::RFB::PIX_FMT_BGR8}
    #  * {Net::RFB::PIX_FMT_BGRA}
    def set_pixel_format(format)
      msg = [0, 0, 0, 0].pack('CC3')
      begin
        @io.syswrite msg

        msg = [
            format[:bpp],
            format[:depth],
            format[:bend],
            format[:tcol],
            format[:rmax],
            format[:gmax],
            format[:bmax],
            format[:rshif],
            format[:gshif],
            format[:bshif],
            0, 0, 0
        ].pack('CCCCS>S>S>CCCC3')
        return @io.syswrite msg

      rescue
        return nil
      end
    end

    # Set way of encoding video frames.
    # @param encodings [Array<Integer>] encoding of video data used to transfer.
    #  * {ENC_RAW}
    #  * {ENC_HEXTILE}
    #  * {ENC_ZRLE}
    def set_encodings(encodings)
      num = encodings.size
      msg = [2, 0, num].pack('CCS>')
      begin
        @io.syswrite msg
        encodings.each do |e|
          @io.syswrite([e].pack('l>'))
        end
      rescue
        return nil
      end
    end

    # Send request for update framebuffer.
    # @param [Integer] inc incremental, request just difference
    #  between previous and current framebuffer state.
    # @param x [Integer]
    # @param y [Integer]
    # @param w [Integer]
    # @param h [Integer]
    def request_update_fb(inc, x: nil, y: nil, w: nil, h: nil)
      ret = nil
      @cb_mutex.synchronize do
        if block_given?
          @call_back = Proc.new { |data| yield data }
        end

        @inc = inc > 0
        msg = [3, inc, x||0, y||0, w||@w, h||@h].pack('CCS>S>S>S>')
        ret = @io.write msg

        if block_given?
          @cb_cv.wait
          ret = @cb_ret
          @cb_ret = nil
        end
      end
      ret
    rescue
      return nil
    end

    # Handle VNC server response. Call it right after +fb_update_request+.
    # @return [Array] type, (either framebuffer, "bell", +handle_server_cuttext+ or +handle_colormap_update+ results)
    def handle_response(t)
      case t
      when 0 then
        handle_fb_updated
        if @call_back
          @cb_mutex.synchronize do
            cb = @call_back
            @call_back = nil
            begin
              @cb_ret = cb.call @data
            ensure
              @cb_cv.broadcast
            end
          end
        end
        return [t, @data]
      when 1 then
        return [t, handle_colormap_update]
      when 2 then
        return [t, 'bell']
      when 3 then
        return [t, handle_server_cuttext]
      else
        return [-1, nil]
      end
    end

    # Receives data and applies diffs(if incremental) to the @data
    def handle_fb_updated
      fail 'run #prepare_framebuffer first' unless @data
      enc = nil
      @encs ||= { 0 => Net::RFB::EncRaw,
                  5 => Net::RFB::EncHextile,
                  16 => Net::RFB::EncZRLE
      }
      _, numofrect = @io.read(3).unpack('CS>')
      i = 0
      while i < numofrect
        hdr = @io.read 12
        x, y, w, h, enc = hdr.unpack('S>S>S>S>l>')
        mod = @encs.fetch(enc) { fail "Unsupported encoding #{enc}" }
        mod.read_rect @io, x, y, w, h, @bpp, @data, @wb, @h
        i += 1
      end
    end

    # @return [Array] palette
    def handle_colormap_update
      _, first_color, noc = (@io.read 5).unpack('CS>S>')
      palette = []
      noc.times do
        palette << (@io.read 6).unpack('S>S>S>')
      end
      return palette
    rescue
      return nil
    end

    # @return [String] server cut text
    def handle_server_cuttext
      begin
        _, _, _, len = (@io.read 7).unpack('C3L>')
        text = @io.read len
      rescue
        return nil
      end
      text
    end
  end
end