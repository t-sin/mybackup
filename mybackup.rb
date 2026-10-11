# frozen_string_literal: true

class MyBackup
  PROG_NAME = 'mybackup'
  PORG_VERSION = '0.1.0'

  OP_LIST_TARGETS = :'op::list_targets'
  OP_SHOW_CONFIG = :'op::show_config'
  OP_BACKUP = :'op::backup'
end

require 'optparse'
def parse_opt(argv)
  opt = OptionParser.new
  opt.banner = "Usage: #{MyBackup::PROG_NAME} [CONFIG_PATH]"
  opt.version = MyBackup::PORG_VERSION
  opt.on('-l', '--list', 'List all backup targets.') { |v| v }
  opt.on('-c', '--config', 'Show configuration.') { |v| v }
  opt.on('-n', '--dry-run', 'Run backup process without actual rsync command.') { |v| v }

  params = {}

  opt.parse!(argv, into: params)
  opt.help_exit if argv.count != 1

  [argv, params, opt]
end

argv, params, opt = parse_opt ARGV.dup

require_relative 'config'
config = MybackupConfig.new argv, params, opt

require_relative 'logger'
MyLogger.setup(config.log_level, config.log_file)
MyLogger.info config.to_h

require_relative 'backup'
require_relative 'command'

def main(config)
  MyLogger.info "operation = #{config.operation}"
  backups = config.backups.map { |b| Backup.from_h b }

  case config.operation
  when MyBackup::OP_SHOW_CONFIG
    s = config
    MyLogger.info s, only_file: true
    puts s
    puts
  when MyBackup::OP_LIST_TARGETS
    backups.each do |b|
      s = b.show
      MyLogger.info s, only_file: true
      puts s
      puts
    end
  when MyBackup::OP_BACKUP
    backups.each do |b|
      MyLogger.info ''
      b.backup config
      puts
    end
  else
    msg = "unknown operation: #{op}"
    MyLogger.fatal msg
    exit 1
  end

  MyLogger.info ''
  puts
end

main config
