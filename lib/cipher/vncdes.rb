require 'openssl'

# MIT-licensed code by Andrew Dorofeyev
# from https://github.com/d-theus/vncrec-ruby

# The server sends a random 16-byte challenge:
#
#      +--------------+--------------+-------------+
#      | No. of bytes | Type [Value] | Description |
#      +--------------+--------------+-------------+
#      | 16           | U8           | challenge   |
#      +--------------+--------------+-------------+
#
# The client encrypts the challenge with DES (ECB), using a password supplied
# by the user as the key.  To form the key, the password is truncated
# to eight characters, or padded with null bytes on the right.
# Actually, each byte is also reversed. Challenge string is split
# in two chunks of 8 bytes, which are encrypted separately and clashed together
# again. The client then sends the resulting 16-byte response:
#
#      +--------------+--------------+-------------+
#      | No. of bytes | Type [Value] | Description |
#      +--------------+--------------+-------------+
#      | 16           | U8           | response    |
#      +--------------+--------------+-------------+
#
# The protocol continues with the SecurityResult message.

module Cipher
	class VNCDES
		attr_reader :key

		def initialize key
			@key = normalized(key[0..7])
			self
		end

		def encrypt(challenge)
			chunks = [challenge.slice(0, 8), challenge.slice(8, 8)]
			cipher = OpenSSL::Cipher::DES.new(:ECB)
			cipher.encrypt
			cipher.key = self.key
			chunks.reduce('') { |a, e| cipher.reset; a << cipher.update(e) }.force_encoding('UTF-8')
		end

		private

		def normalized(key)
			rev = ->(n) { (0...8).reduce(0) { |a, e| a + 2**e * n[7 - e] } }
			inv = key.each_byte.map { |b| rev[b].chr }.join
			inv.ljust(8, "\x00")
		end
	end
end

