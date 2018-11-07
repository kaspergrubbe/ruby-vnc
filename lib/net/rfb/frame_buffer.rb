require 'thread'
require 'vncrec/constants.rb'
require 'vncrec/rfb/proxy.rb'

begin
  require 'vncrec'
rescue LoadError
  raise 'The "vncrec" gem required for using framebuffer feature, but not installed it.'
end

module Net::RFB

  # Manage FrameBuffer pixel data for RFB protocol
  # This is a little wrapper for the `Proxy` class in vncrec-ruby https://github.com/d-theus/vncrec-ruby
  class FrameBuffer
    class VNCRecAuthStub
      def initialize(io, *options)
      end
    end

    # @param io  [IO, #read, #sysread, #syswrite, #read_nonblock] string stream from VNC server.
    # @param w   [Integer] width of the screen area
    # @param h   [Integer] height of the screen area
    # @param bpp [Symbol] bits per pixel (BGR8 or BGRA)
    # @param encodings [Array<Symbol>] encoding (RAW or HEXTILE or ZRLE) default: RAW
    def initialize(io, w, h, bpp, encodings=nil)
      @cb_mutex = Monitor.new
      @cb_cv = @cb_mutex.new_cond

      @encodings = encodings

      # convert pixel_format symbol to VNCRec::PIX_FMT_XXX symbol.
      pf = bpp.to_s.prepend('PIX_FMT_').upcase.to_sym
      raise ArgumentError, "Unsupported bpp '#{bpp}', now supported values are: BGR8, BGRA" unless VNCRec.const_defined? pf
      @vnc_rec_pix_fmt = VNCRec.const_get(pf)

      @proxy = VNCRec::RFB::Proxy.new(io, nil, nil, nil, [VNCRecAuthStub, nil])
      @proxy.prepare_framebuffer w, h, @vnc_rec_pix_fmt[:bpp]
    end

    def send_initial_data
      # set encoding
      unless self.set_encodings @encodings
        raise 'Error while setting encoding'
      end

      # set pixel format
      self.set_pixel_format @vnc_rec_pix_fmt

      # request all pixel data
      self.request_update_fb 0
    end

    # 8bit pixel data of screen
    def pixel_data
      @proxy.data
    end

    # 16bit pixel data of screen
    def pixel_data_16
      raise 'Unsupported pixel_format. Now supported BGRA format only.' if @vnc_rec_pix_fmt[:string] != 'bgra'
      require 'matrix'
      pxl_data = self.pixel_data.unpack("C*")
      pxl_data_16 = Matrix[pxl_data] * 257  # convert to 2 bytes expression
      pxl_data_16.to_a[0]
    end

    # Set a way that server should use to represent pixel data
    # @param [Hash] pixel format:
    #  * {Net::RFB::PIX_FMT_BGR8}
    #  * {Net::RFB::PIX_FMT_BGRA}
    def set_pixel_format(format)
      @proxy.set_pixel_format format
    end

    # Set way of encoding video frames.
    # @param encodings [Symbol, String] list of encoding of video data used to transfer.
    #  * :RAW
    #  * :HEXTILE
    #  * :ZRLE
    def set_encodings(*encodings)
      @proxy.set_encodings [encodings].flatten.compact.map{|sym| VNCRec::const_get "ENC_#{sym}"}
    end

    # Send request for update framebuffer.
    #  if block given, called it with pixel data after the response received.
    # @param [Integer] inc incremental, request just difference
    #  between previous and current framebuffer state.
    # @param x [Integer]
    # @param y [Integer]
    # @param w [Integer]
    # @param h [Integer]
    # @return if block given, returned value by block, else nil.
    def request_update_fb(inc, x: nil, y: nil, w: nil, h: nil)
      ret = nil
      @cb_mutex.synchronize do
        if block_given?
          @call_back = Proc.new { |data| yield data }
        end

        @proxy.fb_update_request inc, x||0, y||0, w||@proxy.w, h||@proxy.h

        if block_given?
          @cb_cv.wait
          ret = @cb_ret
          @cb_ret = nil
        end
      end
      ret
    end

    def handle_response(t)
      case t
      when 0 # ----------------------------------------------- FramebufferUpdate
        handle_fb_update
        if @call_back
          @cb_mutex.synchronize do
            cb = @call_back
            @call_back = nil
            begin
              @cb_ret = cb.call @proxy.data
            ensure
              @cb_cv.broadcast
            end
          end
        end
        return @proxy.data
      when 1 # --------------------------------------------- SetColourMapEntries
        return handle_set_colormap_entries
      end
    end

    private

    # Receives data and applies diffs(if incremental) to the @data
    def handle_fb_update
      @proxy.handle_fb_update
    end

    # @return [Array] palette
    def handle_set_colormap_entries
      @proxy.handle_colormap_update
    end
  end
end