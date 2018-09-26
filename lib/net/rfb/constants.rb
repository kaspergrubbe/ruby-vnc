# Constants
# Diverted from vncrec-ruby https://github.com/d-theus/vncrec-ruby
module Net::RFB

  ENC_RAW         = 0
  ENC_HEXTILE     = 5
  ENC_ZRLE        = 16

  PIX_FMT_BGR8  = { :bpp=> 8, :depth=> 8, :bend=> 0, :tcol=> 0, :rmax=> 0x7, :gmax=> 0x7, :bmax=> 0x3, :rshif=> 5, :gshif=> 2, :bshif=> 0, string: "bgr8" }
  PIX_FMT_BGRA = { :bpp=> 32, :depth=> 24, :bend=> 0, :tcol=> 1, :rmax=> 0xFF, :gmax=> 0xFF, :bmax=> 0xFF, :rshif=> 16, :gshif=> 8, :bshif=> 0, string: "bgra" }

end
