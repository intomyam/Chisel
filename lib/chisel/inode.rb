module Chisel
  class INode
    require "io/console/size"

    SIZE = 64
    TYPE = {
      UNDEFINED: 0,
      DIRECTORY: 1,
      FILE: 2,
      DEVICE: 3
    }

    attr_accessor :name
    attr_reader :inum, :parent, :nlink, :type, :size

    def initialize(file_system, inum, parent = nil, name = nil)
      @file_system = file_system
      @inum = inum
      @parent = parent
      @name = name
      parse
    end

    def exist_inum?
      @file_system.inode(SIZE, @inum * SIZE) != nil
    end

    def parse
      unless exist_inum?
        @data = []
        return
      end

      @type, @major, @minor, @nlink, @size, *@addrs, @indirect_addr = @file_system.inode(SIZE, @inum * SIZE).unpack("v4V*")

      @data = []
      @addrs.each do |addr|
        @data << Chisel::Data.new(@file_system, addr) unless addr == 0
      end

      unless @indirect_addr == 0
        @data += Chisel::Data.new(@file_system, @indirect_addr).plural_data
      end
    end

    def dir?
      @type == TYPE[:DIRECTORY]
    end

    def undefined?
      @type == TYPE[:UNDEFINED]
    end

    def files
      raise "this is not directory" unless dir?

      @files ||= @data.map(&:files).inject(&:merge)
    end

    def children
      raise "this is not directory" unless dir?

      ret = []

      files.each do |name, inum|
        next if name == '.'
        next if name == '..'

        ret << INode.new(@file_system, inum, self, name)
      end

      ret
    end

    def linked_inodes
      raise "this is not directory" unless dir?
      ret = []

      files.each do |name, inum|
        next if name == '.'
        ret << INode.new(@file_system, inum, self, name)
      end

      ret
    end

    def inum_and_names
      raise "this is not directory" unless dir?

      ret = []
      files.each do |name, inum|
        ret << "#{name}[#{inum}]"
      end

      ret
    end

    def child(name)
      raise "this is not directory" unless dir?

      return nil unless files.has_key?(name)

      if name == "."
        INode.new(@file_system, files[name], @parent, @name)
      elsif name == ".."
        if @parent
          @parent
        else
          self
        end
      else
        INode.new(@file_system, files[name], self, name)
      end
    end

    def ==(other_vec)
      if other_vec.class == self.class
        inum == other_vec.inum
      else
        super other_vec
      end
    end

    def data_size
      @data.count * BLOCK_SIZE
    end

    def used_block_nums
      if @indirect_addr == 0
        @data.map(&:addr)
      else
        @data.map(&:addr) << @indirect_addr
      end
    end

    def to_s
      if dir?
        "<inum=#{@inum}, type=#{@type},  files=#{files}>"
      else
        "<inum=#{@inum}, type=#{@type}>"
      end
    end
  end
end
