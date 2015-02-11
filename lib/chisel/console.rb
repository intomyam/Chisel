module Chisel
  class Console
    require "io/console/size"

    def initialize(file_name)
      @file_name = file_name
      @file_system = Chisel::FileSystem.new(file_name)
    end

    def start
      Signal.trap(:INT){
        puts
        exit(0)
      }

      @now_inode = @file_system.root
      print_path

      loop do
        input = STDIN.gets
        if input.nil?
          puts
          exit(0)
        end

        input = input.chop

        send(input.split(" ").first, input.split(" ")[1..-1]) unless input.empty?
        print_path
      end
    end

    def print_path
      print "[Chisel:console #{@now_inode.name}]$ "
    end

    def ls(args)
      option_p = true if args.first == "-p"

      inodes = []
      @now_inode.children.each do |inode|
        if option_p && inode.dir?
          inodes << "#{inode.name}/[#{inode.inum}]"
        else
          inodes << "#{inode.name}[#{inode.inum}]"
        end
      end

      if inodes.empty?
        puts
        return
      end

      max_size = inodes.map(&:size).max + 1

      text_size = 2
      text_size *= 2 while(text_size < max_size)

      console_size = IO.console_size.last
      count_per_line = 1
      count_per_line *= 2 while(text_size * count_per_line <= console_size)
      count_per_line /= 2 unless count_per_line == 1

      inodes.each_slice(count_per_line) do |inodes_one_line|
        inodes_one_line.each do |inode|
          print inode.ljust(text_size)
        end
        puts
      end
    end

    def cd(args)
      if args.empty?
        @now_inode = @file_system.root
        return
      end

      file_name = args.first
      inode = @now_inode.child(file_name)

      unless inode
        puts "cd: #{file_name}: No such file or directory"
        return
      end

      unless inode.dir?
        puts "cd: #{file_name}:Not a directory"
        return
      end

      @now_inode = inode
    end

    def stat(args)
      if args.empty?
        inode = @now_inode
      else
        file_name = args.first
        inode = @now_inode.child(file_name)
      end

      unless inode
        puts "cd: #{file_name}: No such file or directory"
        return
      end

      puts "Name   : #{inode.name}"
      puts "Number : #{inode.inum}"
      puts "Type   : #{inode.type}"
      puts "Nlink  : #{inode.nlink}"
      puts "Size   : #{inode.size}"
    end

    def sl(args)
      puts "sl: SL not found"
    end

    def method_missing(name, args)
      puts "#{name}: command not found"
    end
  end
end
