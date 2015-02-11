module Chisel
  class FileSystem
    ROOT_INUM = 1
    SUPER_SIZE = 16

    attr_reader :name, :root

    def initialize(name)
      @name = name
      parse
      @root = INode.new(self, ROOT_INUM)
      @root.name = "/"
    end

    def parse
      @total_block_size, @data_block_size, @inode_count, @log_block_size = File.binread(@name, SUPER_SIZE, BLOCK_SIZE).unpack("V4")
      @inode_data = File.binread(@name, inode_block_size * BLOCK_SIZE, 2 * BLOCK_SIZE)
    end

    def inode(limit, offset)
      @inode_data[offset, limit]
    end

    def all_inodes
      return @all_inodes if @all_inodes

      inodes = []
      @inode_count.times do |i|
        inode = INode.new(self, i)
        inodes << inode unless inode.undefined?
      end

      @all_inodes = inodes
    end

    def check
      @messages = []

      check_size
      check_bitmap
      check_root
      check_inodes

      @messages.each do |message|
        puts "     >>>" + message.spot
        puts red("        " + message.body.gsub(/(\r\n|\r|\n)/,"\n        "))
        puts blue("        " + message.postscript.gsub(/(\r\n|\r|\n)/,"\n        "))
        puts
      end

      puts green("no problem.") if @messages.count == 0
    end

    def red(message)
      "\e[31m" + message + "\e[39m"
    end

    def green(message)
      "\e[32m" + message + "\e[39m"
    end

    def blue(message)
      "\e[34m" + message + "\e[39m"
    end

    def check_size
      sum_block_size = 2 + inode_block_size + bitmap_block_size + @data_block_size + @log_block_size

      unless @total_block_size == sum_block_size
        message = Chisel::Message.new
        message.spot = "Size"
        message.body = "total size written by super block does not valid"
        message.postscript = <<-EOS
Written total block : #{@total_block_size}

Boot block   : 1
Super block  : 1
Inode block  : #{inode_block_size}
Bitmap block : #{bitmap_block_size}
Data block   : #{@data_block_size}
Log block    : #{@log_block_size}
Total block  : #{sum_block_size}
        EOS

        @messages << message
      end
    end

    def check_bitmap
      bitmap = active_data_blocks_by_bitmap
      data_blocks = all_inodes.map(&:used_block_nums).flatten

      unless bitmap - data_blocks == []
        message = Chisel::Message.new
        message.spot = "Bitmap"
        message.body = "reffering to unused data block bit should 0"
        message.postscript = "Inode numbers : #{bitmap - data_blocks}"
        @messages << message
      end

      unless data_blocks - bitmap == []
        message = Chisel::Message.new
        message.spot = "Bitmap"
        message.body = "reffering to used data block bit should 0"
        message.postscript = "Inode numbers : #{data_blocks - bitmap}"
        @messages << message
      end
    end

    def active_data_blocks_by_bitmap
      bitmap = File.binread(@name, bitmap_block_size * BLOCK_SIZE, (2 + inode_block_size) * BLOCK_SIZE)
      bitmap = bitmap.unpack("b*").first.gsub(/1/).map{$`.length}.select do |num|
        num >= 2 + inode_block_size + bitmap_block_size && num < @total_block_size - @log_block_size
      end
    end

    def check_root
      me = @root.child(".")
      unless me == @root
        message = Chisel::Message.new
        message.spot = "Root Inode"
        message.body = "'.' should be self"
        message.postscript = <<-EOS
Inode number : #{directory.inum}
. number     : #{me.inum}
        EOS

        @messages << message
      end

      parent = @root.child("..")
      unless parent == @root
        message = Chisel::Message.new
        message.spot = "Root Inode"
        message.body = "'..' should be self"
        message.postscript = <<-EOS
Inode number : #{directory.inum}
.. number    : #{parent.inum}
        EOS
        @messages << message
      end
    end

    def check_inodes
      accessible_inodes = [@root]
      directories = [@root]
      linked_inodes = []

      accessible_inodes.each do |inode|
        if inode.dir?
          children = inode.children
          accessible_inodes << children
          accessible_inodes.flatten!

          linked_inodes += inode.linked_inodes
          directories += children.select(&:dir?)
        end
      end

      check_inodes_type(accessible_inodes)
      check_inodes_nlink(linked_inodes)
      check_dir_inodes(directories - [@root])
    end

    def check_inodes_type(inodes)
      inodes_inum = inodes.map(&:inum).uniq
      all_inodes_inum = all_inodes.map(&:inum)

      unless inodes_inum - all_inodes_inum == []
        message = Chisel::Message.new
        message.spot = "Inode"
        message.body = "accessible inode type should not be 0"
        message.postscript = "Inode numbers : #{inodes_inum - all_inodes_inum}"
        @messages << message
      end

      unless all_inodes_inum - inodes_inum == []
        message = Chisel::Message.new
        message.spot = "Inode"
        message.body = "inaccessible inode type should be 0"
        message.postscript = "Inode numbers : #{all_inodes_inum - inodes_inum}"
        @messages << message
      end
    end

    def check_inodes_nlink(inodes)
      inode_group = inodes.group_by(&:inum)

      error_inodes = []
      inode_group.each do |inum, same_inodes|
        unless same_inodes.first.nlink == same_inodes.count
          error_inodes << "[#{inum}: #{same_inodes.first.nlink},#{same_inodes.count}]"
        end
      end

      unless error_inodes.empty?
        message = Chisel::Message.new
        message.spot = "Inode"
        message.body = "nlink is invalid"
        message.postscript = "[Inode number: nlink, real link count]\n" + error_inodes.join(' ')
        @messages << message
      end
    end

    def check_dir_inodes(inodes)
      inodes.each do |directory|
        me = directory.child(".")
        if me
          unless me == directory
            message = Chisel::Message.new
            message.spot = "Directory Inode"
            message.body = "'.' should be self"
            message.postscript = <<-EOS
Inode number : #{directory.inum}
. number     : #{me.inum}
            EOS

            @messages << message
          end
        else
          message = Chisel::Message.new
          message.spot = "Directory Inode"
          message.body = "'.' should exist"
          message.postscript = "Inode number : #{directory.inum}"

          @messages << message
        end

        parent = directory.child("..")
        if parent
          unless parent == directory.parent
            message = Chisel::Message.new
            message.spot = "Directory Inode"
            message.body = "'..' should be parent"
            message.postscript = <<-EOS
Inode number : #{directory.inum}
.. number    : #{parent.inum}
            EOS

            @messages << message
          end
        else
          message = Chisel::Message.new
          message.spot = "Directory Inode"
          message.body = "'..' should exist"
          message.postscript = "Inode number : #{directory.inum}"

          @messages << message
        end
      end
    end

    private

    def inode_block_size
      ipb = BLOCK_SIZE / INode::SIZE
      (@inode_count / ipb) + 1
    end

    def bitmap_block_size
      (@total_block_size / (BLOCK_SIZE * 8)) + 1
    end
  end
end
