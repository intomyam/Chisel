require "./lib/chisel"

if ARGV[0]
  case ARGV[0]
  when "-r"
    Dir.glob(ARGV[1] + "/**/*.img").each do |file|
      puts file
      chisel = Chisel::FileSystem.new(file)
      chisel.check
      puts
    end
  when "-c"
    Chisel::Console.new(ARGV[1]).start
  else
    chisel = Chisel::FileSystem.new(ARGV[0])
    chisel.check
  end
else
  puts "ファイル名を指定してください"
end
