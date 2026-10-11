# frozen_string_literal: true

require 'optparse'
require 'pp'

class MyBackup
  PROG_NAME = 'mybackup'
  PORG_VERSION = '0.1.0'

  OP_LIST_TARGETS = :'op::list_targets'
  OP_SHOW_CONFIG = :'op::show_config'
  OP_BACKUP = :'op::backup'
end

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
# MyLogger.debug PP.pp config.to_h

require_relative 'backup'
require_relative 'command'

def format_sec(sec)
  sec = sec.truncate
  min, sec = sec.divmod(60)
  hour, min = min.divmod(60)

  "#{hour}h #{min}m #{sec}s"
end

def main(config)
  MyLogger.info "operation = #{config.operation}"
  backups = config.backups.map { |b| Backup.from_h b }

  case config.operation
  when MyBackup::OP_SHOW_CONFIG
    MyLogger.info config
  when MyBackup::OP_LIST_TARGETS
    backups.each do |b|
      b.to_ss.each { |s| MyLogger.info s }
    end
  when MyBackup::OP_BACKUP
    op_start_at = Time.now
    MyLogger.info "=== start backup operation at #{op_start_at.iso8601}"

    backups.each do |b|
      start_at = Time.now
      MyLogger.info "start backup #{b.name} at #{start_at.iso8601}"

      b.backup config

      end_at = Time.now
      MyLogger.info "finished backup #{b.name} at #{end_at.iso8601}"
      MyLogger.info "it took #{format_sec(end_at - start_at)}"
      MyLogger.info ''
    end

    op_end_at = Time.now
    MyLogger.info "finished backup operation at #{op_end_at.iso8601}"
    MyLogger.info "it took #{format_sec(op_end_at - op_start_at)}"

  else
    msg = "unknown operation: #{op}"
    MyLogger.fatal msg
    exit 1
  end
end

main config
