# frozen_string_literal: true

require 'pp'

class Backup
  attr_reader :id, :name, :from, :to

  def self.hash_has_key?(backup, key)
    return false if backup.key? key

    msg = "backup has no #{key} slot.\nbackup = #{backup}"
    MyLogger.fatal msg
    raise StandardError, msg
  end

  def self.from_h(backup)
    hash_has_key? backup, 'id'
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

  def to_ss
    msg = 'there is no info to show'
    MyLogger.fatal msg
    raise NotImplementedError, msg
  end

  def setup(_config); end

  def backup(_config)
    msg = 'there is no info to run backup'
    MyLogger.fatal msg

    raise NotImplementedError, msg
  end

  def initialize(id, name, from, to)
    @id = id
    @name = name
    @from = from
    @to = to
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
      # '--out-format="%t %i %o %n%L"',             # コンソール出力フォーマット:
      '--quiet',                                  # stdoutのログはなし
      '--log-file-format="%t %i %o %n%L"',        # ログファイル出力フォーマット:
      "--log-file=#{log_file}" # ログファイル名
    ]
    base_options + options
  end
end

class LocalBackup < Backup
  def self.from_h(backup)
    new backup['id'], backup['name'], backup['from'], backup['to']
  end

  def initialize(id, name, from, to)
    super
    MyLogger.debug("local backup: #{id}, name = #{name}, from = #{from}, to = #{to}")
  end

  def to_ss
    [
      'LocalBackup',
      "    id = #{@id}",
      "  name = #{@name}",
      "  from = #{@from}",
      "    to = #{@to}"
    ]
  end

  def backup(config)
    options = []
    cmd = RsyncCommand.new(
      @from, @to,
      dry_run: config.dry_run,
      options: rsync_options(config.log_file, options),
      exclude_patterns: config.exclude_patterns
    )
    to_ss.each { |s| MyLogger.info s }

    ret = cmd.run
    return if ret

    MyLogger.info("backup failed; return code = #{ret}")
    raise StandardError
  end
end

class RemoteBackup < Backup
  attr_reader :identity_file

  def self.from_h(backup)
    hash_has_key? backup, 'identity_file'

    new backup['id'], backup['name'], backup['from'], backup['to'], backup['identity_file']
  end

  def initialize(id, name, from, to, identity_file)
    super(id, name, from, to)
    @identity_file = identity_file
    MyLogger.debug("remote backup: #{id}, name = #{name}, from = #{from}, to = #{to}, identity_file = #{identity_file}")
  end

  def to_ss
    [
      'RemoteBackup',
      "       id = #{@id}",
      "     from = #{@from}",
      "       to = #{@to}",
      "  id_file = #{@identity_file}"
    ]
  end

  def setup(config)
    idfile = File.expand_path @identity_file
    SshAddCommand.new(idfile, dry_run: config.dry_run).run
  end

  def backup(config)
    options = ['--rsh=ssh -T']
    cmd = RsyncCommand.new(
      @from, @to,
      dry_run: config.dry_run,
      options: rsync_options(config.log_file, options),
      exclude_patterns: config.exclude_patterns
    )
    to_ss.each { |s| MyLogger.info s }

    ret = cmd.run
    return if ret

    MyLogger.info("backup failed; return code = #{ret}")
    raise StandardError
  end
end
