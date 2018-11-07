require 'thread'

begin
  require 'vncrec'
  require 'vncrec/constants.rb'
  require 'vncrec/rfb/proxy.rb'
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

      @vnc_rec_pix_fmt = convert_to_vnc_rec_pix_fmt bpp

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
      self.request_update_fb incremental: false
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
    # @param [Symbol|String] pixel format:
    #  * :BGR8
    #  * :BGRA
    def set_pixel_format(format)
      @proxy.set_pixel_format convert_to_vnc_rec_pix_fmt(format)
    end

    # Set way of encoding video frames.
    # @param encodings [Symbol|String] list of encoding of video data used to transfer.
    #  * :RAW
    #  * :HEXTILE
    #  * :ZRLE
    def set_encodings(*encodings)
      @proxy.set_encodings [encodings].flatten.compact.map{|sym| VNCRec::const_get "ENC_#{sym}"}
    end

    # Send request for update framebuffer.
    #  if block given, called it with pixel data after the response received.
    # @param [Boolean] incremental incremental, request just difference
    #  between previous and current framebuffer state.
    # @param x [Integer]
    # @param y [Integer]
    # @param w [Integer]
    # @param h [Integer]
    # @param wait_for_response [Boolean] if true, wait for a FramebufferUpdate response
    def request_update_fb(incremental: true, x: nil, y: nil, w: nil, h: nil, wait_for_response: false)
      @cb_mutex.synchronize do
        @proxy.fb_update_request incremental ? 1 : 0, x||0, y||0, w||@proxy.w, h||@proxy.h

        if wait_for_response
          @cb_cv.wait
        end
      end
    end

    def handle_response(t)
      case t
      when 0 # ----------------------------------------------- FramebufferUpdate
        ret = handle_fb_update
        @cb_mutex.synchronize do
          @cb_cv.broadcast
        end
        return ret
      when 1 # --------------------------------------------- SetColourMapEntries
        return handle_set_colormap_entries
      end
    end

    def save_screenshot(dest)
      begin
        require 'rmagick'
      rescue LoadError
        raise 'The "rmagick" gem required for using save screenshot feature, but not installed it.'
      end

      self.request_update_fb(wait_for_response: true)

      px = self.pixel_data_16
      raise 'Error in get_screen_pixel_data.' unless px
      image = Magick::Image.new(@proxy.w, @proxy.h)
      image.import_pixels(0, 0, @proxy.w, @proxy.h, 'BGRO', px)
      if dest.is_a? IO
        dest.write image.to_blob
      elsif dest.is_a?(String) || dest.is_a?(Pathname)
        image.write dest.to_s
      else
        raise ArgumentError, "Unsupported destination type #{dest.inspect}"
      end
    ensure
      image.destroy! if image
    end

    private

    # convert pixel_format symbol to VNCRec::PIX_FMT_XXX symbol.
    # @param pix_fmt [Symbol|String] bits per pixel (BGR8 or BGRA)
    def convert_to_vnc_rec_pix_fmt(pix_fmt)
      return pix_fmt if pix_fmt.is_a?(Hash)
      pf = pix_fmt.to_s.prepend('PIX_FMT_').upcase.to_sym
      raise ArgumentError, "Unsupported pixel_format '#{pix_fmt}', now supported values are: BGR8, BGRA" unless VNCRec.const_defined? pf
      VNCRec.const_get(pf)
    end

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