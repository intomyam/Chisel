module Chisel
  require_relative 'chisel/file_system'
  require_relative 'chisel/inode'
  require_relative 'chisel/data'
  require_relative 'chisel/message'
  require_relative 'chisel/console'

  BLOCK_SIZE = 512
  BLOCK_NUM_SIZE = 4
end
