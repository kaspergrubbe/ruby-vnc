module Net
  module RFB

    # Encoder of Raw encode type for RFB protocol
    # Diverted from vncrec-ruby https://github.com/d-theus/vncrec-ruby
    module EncRaw
      def self.read_rect(io, x, y, w, h, bitspp, fb, fbw, fbh)
        bytespp = (bitspp.to_f / 8.0).to_i
        rectsize = w * h * bytespp
        data = io.read(rectsize)

        if (x + w) * bytespp > fbw
          if x * bytespp > fbw
            return
          else
            w = fbw / bytespp - x
          end
        end
        if (y + h) > fbh
          if y > fbh
            return
          else
            h = fbh - y
          end
        end

        row = 0
        while row < h
          topleft = fbw * (y + row) + x * bytespp
          fb[topleft ... topleft + w * bytespp] = data[row * w * bytespp ... (row + 1) * w * bytespp]
          row += 1
        end
      end
    end
  end
end
