require 'spec_helper'
require 'net/vnc'

=begin
class SocketMock
	class MockIOError < IOError
	end

	def initialize
		# this can be used to make detailed assertions
		@trace = []
		@read_buf  = ''
		@write_buf = ''
	end

	def read len
		@trace << [:read, len]
		if @read_buf.length < len
			msg = 'bad socket read sequence - read(%d) but only %d byte(s) available' % [len, @read_buf.length]
			raise MockIOError, msg
		end
		@read_buf.slice! 0, len
	end

	def write data
		@trace << [:write, data]
		@write_buf << data
	end
end

class VNCServerSocketMock < SocketMock
	TICK_TIME = 0.1

	def initialize(&block)
		super

		@pending_read = nil
		obj = self
		@t = Thread.new { block.call obj; @pending_read = nil }
		100.times do |i|
			break if @pending_read
			if i == 99
				msg = 'blah'
				raise MockIOError, msg
			end
			sleep TICK_TIME
		end
	end

	def run
		yield
		100.times do |i|
			break unless @pending_read
			if i == 99
				msg = 'missing socket write sequence'
				raise MockIOError, msg
			end
			sleep TICK_TIME
		end
		raise 'wrote to much' if @write_buf.length != 0
		raise 'did not read enough' if @read_buf.length != 0
	end

	def read len
		@trace << [:read, len]
		100.times do |i|
			break if @read_buf.length >= len
			if i == 99
				msg = 'timeout during socket read sequence - read(%d) but only %d byte(s) available' % [len, @read_buf.length]
				raise MockIOError, msg
			end
			sleep TICK_TIME
		end
		@read_buf.slice! 0, len
	end

	def write data
		unless @read_buf.empty?
			raise MockIOError, 'tried to write with non empty read buffer - (%p, %p)' % [@read_buf, data]
		end
		super
		if !@pending_read
			raise MockIOError, "wrote to socket but server is not expecting it"
		end
		if @write_buf.length >= @pending_read
			@pending_read = @write_buf.slice!(0, @pending_read)
			sleep TICK_TIME while @pending_read.is_a? String
		end
	end

	def provide_data data
		@read_buf << data
	end

	def expect_data len
		@pending_read = len
		sleep TICK_TIME while @pending_read.is_a? Fixnum
		@pending_read
	end
end

describe 'Net::VNC' do
	VNC = Net::VNC

	it 'should do something' do
=begin
		socket_mock.should_receive(:read).once.ordered.with(12).and_return("RFB 003.003\n")
		socket_mock.should_receive(:write).once.ordered.with(/^RFB (\d{3}.\d{3})\n$/)
		socket_mock.should_receive(:read).once.ordered.with(4).and_return([1].pack('N'))
		socket_mock.should_receive(:write).once.ordered.with("\000")
		socket_mock.should_receive(:read).once.ordered.with(20).and_return('')
		socket_mock.should_receive(:read).once.ordered.with(4).and_return([0].pack('N'))
		#m = mock('my mock')
		#m.should_receive(:test1).ordered.once.with('argument').and_return(1)
		#m.should_receive(:test2).ordered.once.with('argument').and_return(2)
		#p m.test1('argument')
		#p m.test2('argument')
		vnc = VNC.open('192.168.0.1:0')
#=end

		server = VNCServerSocketMock.new do |s|
			s.provide_data "RFB 003.003\n"
			p :read => s.expect_data(12)
			s.provide_data [1].pack('N')
			p :read => s.expect_data(1)
			s.provide_data ' ' * 20
			s.provide_data [0].pack('N')
		end
		server.run do
			TCPSocket.should_receive(:open).with('192.168.0.1', 5900).and_return(server)
			vnc = VNC.open('192.168.0.1:0')
		end
	end
end
=end

