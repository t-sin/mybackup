# frozen_string_literal: true

def remove_last_slash(s)
  s.chop! if s.end_with? '/'
  s
end

class Backup
  def self.hash_has_key?(backup, key)
    return false if backup.key? key

    MyLogger.fatal("backup has no #{key} slot.\nbackup = #{backup}")
    raise StandardError
  end

  def self.from_h(backup)
    hash_has_key? backup, 'name'
    hash_has_key? backup, 'type'
    hash_has_key? backup, 'from'
    hash_has_key? backup, 'to'

    case backup['type']
    when 'local'
      LocalBackup.from_h backup
    when 'remote'
      RemoteBackup.from_h backup
    else
      raise Error, "unknown backup type: #{backup['type']}"
    end
  end

  def show
    msg = 'there is no info to show'
    MyLogger.fatal msg
    raise NotImplementedError, msg
  end

  def backup(_config)
    msg = 'there is no info to run backup'
    MyLogger.fatal msg

    raise NotImplementedError, msg
  end

  def rsync_options(log_file, options = [])
    base_options = [
      #  '--exclude=\'Application Data\''         #  対象外パス
      #  同期オプション
      '--archive',                                # アーカイブモード (パーミッション保持)
      '--delete',                                 # destにあってsrcにないファイルは削除
      #      '--checksum',                        # 同期有無の判定をチェックサムで行う
      #      '--partial',                         # 転送途中ファイルを残す (再開時は続きから)
      #      '--append-verify',                   # 既存ファイルに追記する (再開時はチェックサム検証して再開)
      '--verbose',
      #  出力オプション
      '--itemize-changes',                        # 同期された理由を表示
      '--human-readable',                         # ファイルザイズをK, M, Gとかにする
      '--out-format="%t %i %o %n%L"',             # コンソール出力フォーマット:
      '--log-file-format="%t %i %o %n%L"',        # ログファイル出力フォーマット:
      "--log-file=#{log_file}" # ログファイル名
    ]
    base_options + options
  end
end

class LocalBackup
  def self.from_h(backup)
    new backup['name'], backup['from'], backup['to']
  end

  def initialize(name, from, to)
    @name = name
    @from = from
    @to = to
    MyLogger.debug("local backup: #{name}, from = #{from}, to = #{to}")
  end

  def show
    [
      'LocalBackup',
      "  name = #{@name}",
      "  from = #{@from}",
      "  to   = #{@to}"
    ].join("\n")
  end

  def backup(config)
    from = remove_last_slash @from
    to = remove_last_slash @to
    options = []
    cmd = RsyncCommand.new(
      from, to,
      dry_run: config.dry_run,
      options: rsync_options(config.log_file, options),
      exclude_patterns: config.exclude_patterns
    )

    MyLogger.info('********** dry run!!!!! **********') if config.dry_run
    MyLogger.info("local backap '#{@name}'")
    MyLogger.info("  from = #{@from}, to = #{@to}")
    MyLogger.info("  command = #{cmd}")

    ret = cmd.run
    unless ret
      MyLogger.info("backup failed; return code = #{ret}")
      raise StandardError
    end
    MyLogger.info('backup finished')
  end
end

class RemoteBackup
  attr_reader :host, :identity_file

  def self.from_h(backup)
    superclass.hash_has_key? backup, 'identity_file'

    new backup['name'], backup['from'], backup['to'], backup['host'], backup['identity_file']
  end

  def initialize(name, from, to, host, identity_file)
    @name = name
    @from = from
    @to = to
    @host = host
    @identity_file = identity_file
    MyLogger.debug("remote backup: #{name}, from = #{from}, to = #{to}, host = #{host}, identity_file = #{identity_file}")
  end

  def show
    [
      'RemoteBackup',
      "  name = #{@name}",
      "  from = #{@from}",
      "  to = #{@to}",
      "  identity_file = #{@identity_file}"
    ].join("\n")
  end

  def backup(config)
    from = remove_last_slash @from
    to = remove_last_slash @to
    options = ["--rsh=ssh -i #{@identity_file}"]
    cmd = RsyncCommand.new(
      from, to,
      dry_run: config.dry_run,
      options: rsync_options(config.log_file, options),
      exclude_patterns: config.exclude_patterns
    )

    MyLogger.info("remote backap '#{@name}'")
    MyLogger.info("  from = #{@from}, to = #{@to}")
    MyLogger.info("  host = #{@host}, identity_file = #{@dentity_file}")
    MyLogger.info("  command = #{cmd}")

    ret = cmd.run
    unless ret
      MyLogger.info("backup failed; return code = #{ret}")
      raise StandardError
    end
    MyLogger.info('backup finished')
  end
end
