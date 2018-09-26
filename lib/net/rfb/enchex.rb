module Net
  module RFB

    # Encoder of Hextile for RFB protocol
    # Diverted from vncrec-ruby https://github.com/d-theus/vncrec-ruby
    module EncHextile
      def EncHextile.read_rect(io,w,h,bitspp)
        bpp = (bitspp.to_f/8.0).to_i
        framebuffer = Array.new(w*h*bpp,0)
        tiles_row_num = (h.to_f/16.0).ceil
        tiles_col_num = (w.to_f/16.0).ceil
        last_tile_w = w % 16
        last_tile_h = h % 16

        prev_tile_bg = nil
        prev_tile_fg = nil

        tiles_row_num.times do |i|

          th = if ((i == tiles_row_num-1) and (last_tile_h > 0)) 
                 last_tile_h
               else
                 16
               end
          ty = 16 * i

          tiles_col_num.times do |j|

            tw = if ((j == tiles_col_num-1) and (last_tile_w > 0))
                   last_tile_w
                 else
                   16
                 end

            tx = 16 * j

            subenc = io.readbyte

            raw = subenc & 1 > 0
            bg_spec = subenc & 2 > 0
            fg_spec = subenc & 4 > 0 
            any_subr = subenc & 8 > 0
            subr_col = subenc & 16 > 0

            if raw
              data = io.read(tw*th*bpp).unpack("C*")
              th.times do |ti|
                init = (ty + ti) * w + tx
                init *= bpp
                towrite = data[ti*tw*bpp ... (ti+1)*tw*bpp ]
                framebuffer[ init ... init + tw * bpp] = towrite
              end
              next
            end

            if bg_spec

              prev_tile_bg = io.readpartial(bpp).unpack("C"*bpp)
            end

            th.times do |ti|
              init = (ty + ti)*w + tx
              init *= bpp
              framebuffer[ init ... init + tw * bpp] = prev_tile_bg * tw
            end

            if fg_spec
              prev_tile_fg = io.readpartial(bpp).unpack("C"*bpp)
            end

            if any_subr
              subrects_number = io.readpartial(1).unpack("C")[0]
              if subr_col
                subrects_number.times do
                  fg = io.readpartial(bpp).unpack("C"*bpp)
                  read_subrect_c w, h ,tx, ty, framebuffer, io, fg
                end
              else
                subrects_number.times do
                  read_subrect_c w, h ,tx, ty, framebuffer, io, prev_tile_fg
                end
              end

            end


          end #tiles_row_num.times
        end #tiles_col_num.times


        return framebuffer.pack("C*")
      end

      def EncHextile.read_subrect(rw, rh, tx, ty, framebuffer, io, fg)
        bpp = fg.size
        xy, wh = io.read(2).unpack("CC")
        x = (xy & 0xF0) >> 4
        y = xy & 0x0F
        w = ((wh & 0xF0) >> 4) + 1
        h = (wh & 0x0F) + 1
        h.times do |sbry|
          init = (ty+sbry+y)*rw + tx + x
          init *= bpp
          framebuffer[init ... init + w * bpp] = fg*w
        end
      end

    end

  end
end
