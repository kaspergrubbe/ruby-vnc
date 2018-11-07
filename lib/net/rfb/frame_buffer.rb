require 'thread'
require 'vncrec/constants.rb'
require 'vncrec/rfb/proxy.rb'

module Net::RFB

  # Manage FrameBuffer pixel data for RFB protocol
  # This is a little wrapper for the `Proxy` class in vncrec-ruby https://github.com/d-theus/vncrec-ruby
  class FrameBuffer
    class VNCRecAuthStub
      def initialize(io, *options)
      end
    end

    # @param io [IO, #read, #sysread, #syswrite, #read_nonblock] string stream from VNC server.
    # @param w width of the screen area
    # @param h height of the screen area
    # @param bpp bits per pixel
    def initialize(io, w, h, bpp)
      @cb_mutex = Monitor.new
      @cb_cv = @cb_mutex.new_cond

      @proxy = VNCRec::RFB::Proxy.new(io, nil, nil, nil, [VNCRecAuthStub, nil])
      @proxy.prepare_framebuffer w, h, bpp
    end

    # 8bit pixel data of screen
    def pixel_data
      @proxy.data
    end

    # 16bit pixel data of screen
    def pixel_data_16
      raise 'Unsupported pixel_format. Now supported BGRA format only.' if @pix_format[:string] != 'bgra'
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
    # @param encodings [Array<Symbol>] encoding of video data used to transfer.
    #  * :ENC_RAW
    #  * :ENC_HEXTILE
    #  * :ENC_ZRLE
    def set_encodings(encodings)
      @proxy.set_encodings [encodings].flatten.compact.map{|sym| VNCRec::const_get sym}
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