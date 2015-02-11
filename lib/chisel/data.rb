module Chisel
  class Data
    def initialize(file_system, addr)
      @file_system = file_system
      @addr = addr
    end

    def addr
      @addr
    end

    def plural_data
      addrs = File.binread(@file_system.name, BLOCK_SIZE, @addr * BLOCK_SIZE).
        each_char.each_slice(BLOCK_NUM_SIZE).map{|addr| addr.join.unpack("V").first }

      ret = []
      addrs.each do |addr|
        ret << Data.new(@file_system, addr) unless addr == 0
      end

      ret
    end

    def files
      files = File.binread(@file_system.name, BLOCK_SIZE, @addr * BLOCK_SIZE).
        each_char.each_slice(16).map{|a| [a[2..-1].join.unpack("Z*").first, a.join.unpack("v").first]}

      ret = {}
      files.each do |key, value|
        next if key.empty?
        ret[key] = value
      end

      ret
    end
  end
end
