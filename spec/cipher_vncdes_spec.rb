require 'spec_helper'
require 'cipher/vncdes'

RSpec.describe Cipher::VNCDES do
  it 'should pad key with zeroes if key is shorter than 8 characters' do
    key = Cipher::VNCDES.new('test').key

    expect(key.size).to eq 8
    expect(key[4..7]).to eq(0.chr * 4)
  end

  it 'should cut the key if the key is longer than 8 characters' do
    expect(Cipher::VNCDES.new('iamdefinitelylongerthan8characters').key.size).to eq 8
  end

  it 'should correctly encrypt keys' do
    encrypted_string = Cipher::VNCDES.new("matzisnicesowearenice").encrypt("\x9D\xBBU\n\x05b\x96L \b'&\x18\xCE(\xD8")
    expect(encrypted_string.encoding.to_s).to eq 'UTF-8'
    expect(encrypted_string.size).to eq 16
    expect(encrypted_string).to eq "2\x95\xA7\xAE\xD4A\xF3\xDCt\x82d\e\xAE\x8A\xB9c"
  end
end
