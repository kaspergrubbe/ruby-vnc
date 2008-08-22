require File.dirname(__FILE__) + '/spec_helper'
require 'cipher/des'

describe 'Cipher::DES' do
	DES = Cipher::DES

	DATA = [
		['0xcafecafecafecafe', :encrypt, [
			11571950, 6765055, 15777490, 16705475, 7667282, 16705355, 6747478, 16709450, 7259479,
			16578410, 7323963, 16580202, 11502011, 16580218, 12520091, 12451450, 3759051, 13328317,
			3242445, 14375869, 1142229, 13851581, 5598645, 13843389, 14132645, 15940541, 14386855,
			7551935, 16356014, 7813567, 14794410, 12511175
		], [
			738924839, 154022719, 1010515743, 185740803, 490290973, 252849675, 420822813, 789982986,
			454377245, 739708714, 453263161, 1010503466, 721829689, 943394618, 791293753, 807083834,
			237974078, 353056061, 203896366, 386741565, 70726702, 370488637, 355873838, 372585277,
			890649646, 975516477, 907680814, 942093119, 1040850214, 422458175, 943337247, 455749127
		], [276147755, 314564801]],
		['0xcafecafecafecafe', :decrypt, [
			14794410, 12511175, 16356014, 7813567, 14386855, 7551935, 14132645, 15940541, 5598645,
			13843389, 1142229, 13851581, 3242445, 14375869, 3759051, 13328317, 12520091, 12451450,
			11502011, 16580218, 7323963, 16580202, 7259479, 16578410, 6747478, 16709450, 7667282,
			16705355, 15777490, 16705475, 11571950, 6765055
		], [
			943337247, 455749127, 1040850214, 422458175, 907680814, 942093119, 890649646, 975516477,
			355873838, 372585277, 70726702, 370488637, 203896366, 386741565, 237974078, 353056061,
			791293753, 807083834, 721829689, 943394618, 453263161, 1010503466, 454377245, 739708714,
			420822813, 789982986, 490290973, 252849675, 1010515743, 185740803, 738924839, 154022719
		], [3868695016, 412139341]],
		['0xdeadbeefdeadbeef', :encrypt, [
			7466991, 16631125, 16695036, 16227052, 14614126, 5292027, 15400830, 4176957, 15531887,
			7044594, 14942075, 3008831, 15597555, 15162582, 16252891, 13468671, 11426815, 16115512,
			12548989, 7945806, 9404409, 16576702, 14647293, 2457327, 14680009, 12499187, 6029295,
			10997623, 16383439, 2076626, 14630590, 13906815
		], [
			473906965, 506403861, 1060846891, 725367084, 926487615, 791546683, 977080112, 792607549,
			993860151, 254752562, 943524644, 1060838975, 993999155, 523449622, 1027552015, 1058740287,
			724516124, 624893496, 791486009, 926749454, 591347458, 926486334, 926878011, 926750511,
			926887715, 1057565491, 373238077, 1060060215, 1043793727, 521091602, 926561549, 859702079
		], [1755543026, 929731926]],
		['0xdeadbeefdeadbeef', :decrypt, [
			14630590, 13906815, 16383439, 2076626, 6029295, 10997623, 14680009, 12499187, 14647293,
			2457327, 9404409, 16576702, 12548989, 7945806, 11426815, 16115512, 16252891, 13468671,
			15597555, 15162582, 14942075, 3008831, 15531887, 7044594, 15400830, 4176957, 14614126,
			5292027, 16695036, 16227052, 7466991, 16631125
		], [
			926561549, 859702079, 1043793727, 521091602, 373238077, 1060060215, 926887715, 1057565491,
			926878011, 926750511, 591347458, 926486334, 791486009, 926749454, 724516124, 624893496,
			1027552015, 1058740287, 993999155, 523449622, 943524644, 1060838975, 993860151, 254752562,
			977080112, 792607549, 926487615, 791546683, 1060846891, 725367084, 473906965, 506403861
		], [2531611598, 527835150]]
	]

	describe '(private class methods)' do
		it 'can prepare keys for encryption and decryption' do
			DATA.each do |hex_key, mode, stage1, stage2, expect|
				key = [hex_key[2..-1]].pack('H*')
				DES.send(:prepare_key_stage1, key, mode).should == stage1
				DES.send(:prepare_key_stage2, stage1).should == stage2
			end
		end

		it 'can prepare perform a DES round on a block of data' do
			DATA.each do |hex_key, mode, stage1, stage2, expect|
				DES.send(:desfunc, [0, 0], stage2).should == expect
			end
		end
	end

	describe '#initialize' do
		it 'can create a DES object from a key and a mode' do
			hex_key, mode, stage1, stage2, expect = DATA[0]
			key = [hex_key[2..-1]].pack('H*')
			des = DES.new key, mode
			des.key.should == key
			des.mode.should == mode
			des.instance_variable_get(:@buf).should == ''
			des.instance_variable_get(:@keys).should == stage2
		end

		it 'will reject invalid modes' do
			lambda { DES.new 'key', :encryptify }.should raise_error(ArgumentError)
		end

		it 'expands or truncates the key to 8 bytes' do
			DES.new('my-really-long-key', :encrypt).key.should == 'my-reall'
			DES.new('key', :encrypt).key.should == "key\000\000\000\000\000"
		end
	end

	describe '#update' do
		before :each do
			hex_key, mode, stage1, stage2, @expect = DATA[0]
			key = [hex_key[2..-1]].pack('H*')
			@des = DES.new key, mode
		end

		it 'will return the data in ciphered form' do
			@des.update([0, 0].pack('N2')).should == @expect.pack('N2')
		end

		it 'will store the residual in buffer' do
			@des.update([0].pack('N')).should == ''
			@des.instance_variable_get(:@buf).should == [0].pack('N')
			@des.update([0].pack('N')).should == @expect.pack('N2')
			@des.instance_variable_get(:@buf).should == ''
		end
	end

	describe '#final' do
		before :each do
			hex_key, mode, stage1, stage2, @expect = DATA[0]
			key = [hex_key[2..-1]].pack('H*')
			@des = DES.new key, mode
		end

		it 'will flush the buffer by padding with null bytes' do
			@des.final.should == ''
			@des.update([0].pack('N')).should == ''
			@des.final.should == @expect.pack('N2')
		end
	end

	describe '.encrypt' do
		it 'is a shortcut class method for DES encryption' do
			hex_key, mode, stage1, stage2, expect = DATA[0]
			key = [hex_key[2..-1]].pack('H*')
			mode.should == :encrypt
			DES.encrypt(key, [0].pack('N')).should == expect.pack('N2')
		end
	end

	describe '.decrypt' do
		it 'is a shortcut class method for DES decryption' do
			hex_key, mode, stage1, stage2, expect = DATA[1]
			key = [hex_key[2..-1]].pack('H*')
			mode.should == :decrypt
			DES.decrypt(key, [0].pack('N')).should == expect.pack('N2')
		end
	end
end

