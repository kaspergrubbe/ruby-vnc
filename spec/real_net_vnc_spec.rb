require 'spec_helper'
require 'net/vnc'

RSpec.describe Net::VNC do
  NO_AUTH_SERVER_DISPLAY   = ':1'
  WITH_AUTH_SERVER_DISPLAY = ':2'

  context 'no auth' do
    it 'should connect with no password' do
      Net::VNC.open(NO_AUTH_SERVER_DISPLAY) do |vnc|
        vnc.pointer_move(10,15)
        expect(vnc.pointer.x).to eq 10
        expect(vnc.pointer.y).to eq 15

        vnc.pointer_move(20,25)
        expect(vnc.pointer.x).to eq 20
        expect(vnc.pointer.y).to eq 25
      end
    end

    it 'should connect with password even though it is not needed' do
      Net::VNC.open(NO_AUTH_SERVER_DISPLAY, password: 'password') do |vnc|
        vnc.pointer_move(10,15)
        expect(vnc.pointer.x).to eq 10
      end
    end
  end

  context 'with auth' do
    it 'should connect with a password' do
      Net::VNC.open(WITH_AUTH_SERVER_DISPLAY, password: 'matzisnicesowearenice') do |vnc|
        vnc.pointer_move(10,15)
        expect(vnc.pointer.x).to eq 10
        expect(vnc.pointer.y).to eq 15
      end
    end

    it 'should give error with a wrong password' do
      expect { Net::VNC.open(WITH_AUTH_SERVER_DISPLAY, password: 'wrongPasssword') }.to raise_error(RuntimeError, 'Unable to authenticate - 1')
    end

    it 'should give error with no password' do
      expect { Net::VNC.open(WITH_AUTH_SERVER_DISPLAY) }.to raise_error(RuntimeError, 'Need to authenticate but no password given')
    end
  end
end
