module Net
  module RFB

    # Encoder of ZRLE for RFB protocol
    # Diverted from vncrec-ruby https://github.com/d-theus/vncrec-ruby
    module EncZRLE

      class Stream

        def initialize(io,bitspp,depth)
          @io = io
          @zstream = Zlib::Inflate.new
          @bpp_orig = (bitspp.to_f/8.0).ceil
          @bpp = case bitspp
                 when 32 then 
                   @depth <= 24 ? 3 : 4
                 when 8 then
                   1
                 else
                   raise "Cannot handle such pixel format"
                 end
          @depth = depth
        end

        def read_zchunk
          zdata_len = (@io.readpartial 4).unpack("L>")[0]
          zdata = ""
          to_read = zdata_len

          while zdata.size < zdata_len
            zdata += @io.read(to_read)
            to_read = zdata_len - zdata.size
          end
          return zdata
        end

        def read_rect(w,h)
          fb = Array.new(w*h*@bpp)
          data = ""
          begin
            data = @zstream.inflate(read_zchunk)
          rescue Zlib::DataError
            return
          end

          stream = StringIO.new data

          tile_cols = (w.to_f/64).ceil
          tile_rows = (h.to_f/64).ceil
          tile_cols_rem = w % 64
          tile_rows_rem = h % 64

          tile_rows.times do |tile_row_num|
            tile_cols.times do |tile_col_num|
              th = if ((tile_row_num == tile_rows-1) and (tile_rows_rem > 0)) 
                     tile_rows_rem
                   else
                     64
                   end
              tw = if ((tile_col_num == tile_cols-1) and (tile_cols_rem > 0))
                     tile_cols_rem 
                   else
                     64
                   end

              subenc = stream.readbyte
              tile = case subenc
                     when 0 then 		#Raw
                       tile = Array.new(tw*th)
                       th.times do
                         tile << (stream.read tw*@bpp_orig).unpack("C*").join
                       end
                       tile
                     when 1 then 		#Solid
                       Array.new(tw*th, stream.read(@bpp_orig))
                     when 2..16 then 		#Packed palette
                       handle_ZRLE_packed_palette(stream, subenc, tw,th)
                     when 128 then 		#Plain RLE
                       handle_ZRLE_plain_RLE_tile(stream,tw,th)
                     when 130..255 then 	#RLE w/ palette
                       handle_ZRLE_palette_RLE_tile(stream,subenc-128, tw,th)
                     end

              th.times do |y|
                boline = (64 * tile_row_num + y) * w
                offx = 64 * tile_col_num
                fb[(boline+offx)...(boline+offx+tw)] = tile[(tw*y)...(tw*(y+1))]
              end
            end  #tile_col.times
          end#tile_row.times
          return fb.join
        end

        def handle_ZRLE_palette_RLE_tile(stream,psize,tw=64,th=64)
          palette = []
          pixels = Array.new(tw*th)
          psize.times do
            palette << stream.read(@bpp)
          end
          len = 0
          begin
            while len < tw*th
              id = stream.read(1).unpack("C")[0]
              #
              #+--------+--------+--------+--------+
              #|   id   |   255  |   ..   |  <255  |
              #+--------+--------+--------+--------+
              #
              if (id & 0b10000000) == 0 
                rl = 1
              else
                id -= 128
                rl = 0
                rem = 0
                while (rem = stream.readbyte) == 255
                  rl += 255
                end
                rl += rem + 1 
              end
              pixels[len...(len+rl)] = Array.new(rl, palette[id]) #TODO: if rl == 1 
              len += rl
            end
          rescue EOFError
          end
          pixels
        end

        def handle_ZRLE_plain_RLE_tile(stream,tw=64,th=64)
          pixels = Array.new(tw*th)
          len = 0
          begin
            while len < tw*th
              color = stream.read(@bpp)
              #
              #+--------+--------+--------+--------+
              #|  color |   255  |   ..   |  <255  |
              #+--------+--------+--------+--------+
              #
              rl = 0
              rem = 0
              while (rem = stream.readbyte) == 255
                rl += 255
              end
              rl += rem + 1 
              pixels[len...(len+rl)] = Array.new(rl, color) #TODO: if rl == 1 
              len += rl
            end
          rescue EOFError
          end
          pixels
        end

        def handle_ZRLE_packed_palette(stream, psize, tw=64, th=64)
          pixels = Array.new(tw*th, 0)
          bitspp = case psize
                   when 2 then 1
                   when 3..4 then 2
                   when 5..16 then 4
                   else 
                     return pixels
                   end
          palette = []
          psize.times do
            palette << stream.read(@bpp).unpack("C*")
          end
          count = case psize
                  when 2 then th*((tw+7)/8)
                  when 3..4 then th*((tw+3)/4)
                  when 5..16 then th*((tw+1)/2)
                  end
          off_bits = 0
          bits_per_row = bitspp * tw
          padding_bits = bits_per_row % 8
          encoded_len_bits = 64 * (bits_per_row + padding_bits)
          encoded = stream.read(count).unpack("C*")
          pixnum = 0
          while off_bits < (encoded_len_bits - padding_bits - bitspp)
            b1 = encoded[off_bits/8]
            b2 = encoded[off_bits/8 + 1] || 0
            b1 <<= 8
            pixels[pixnum] = palette[h_bitmask(b2 + b1, bitspp, off_bits % 16)].pack("C*")
            off_bits += if (off_bits % bits_per_row) > (bits_per_row - padding_bits) and (padding_bits > 0)
                          bitspp + padding_bits
                        else
                          bitspp
                        end
            pixnum += 1
          end
          pixels
        end
      end


    end

  end
end

def h_bitmask(input,count,offset=0)
  #return first n bits of ushort as integer
  #TODO: make generalization of input type
  input <<= offset
  (input & (0xFFFF - 2**(16-count) + 1)) >> (16 - count)
end
