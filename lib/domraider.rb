require 'rubygems'
require 'ostruct'
require 'logger'
require 'sys/filesystem'

module Domraider

  VERSION = "0.3.20090818103235"
  CODENAME = "This ain't crap"

  def self.log
    if not defined? @@logger
      @@logger = Logger.new(STDOUT)
      @@logger.level = Logger::DEBUG
    end
    @@logger
  end

  module Util

    #
    # mount the logical volume in a random dir under
    # /tmp
    #
    # returns the target dir if success, nil otherwise
    #
    def self.lv_mount(vgname, lvname)
      File.open('/proc/mounts') do |f|
        f.each do |l|
          if l =~ /(\/dev\/#{vgname}\/#{lvname}|\/dev\/mapper\/#{vgname}-#{lvname})/
            Domraider.log.error "Logical Volume already mounted"
            raise Exception.new("Logical Volume already mounted")
          end
        end
      end
      mount_fs("/dev/mapper/#{vgname}-#{lvname}")
    end

    #
    # returns the filesystem type or nil if it cant find it
    #
    def self.fs_type(path)
      ret, out = run_command("blkid #{path}") 
      if ret == 0
        out.match(/ TYPE="(.*)"/)
        return $1
      end
      nil
    end

    def self.mount_fs(dev, type = 'block')
      dir = "/tmp/domraider_#{Time.now.to_i}"
      begin
        Dir.mkdir(dir) 
        if type == 'block'
          ret, out = run_command("mount #{dev} #{dir}")
        elsif type == 'sparse'
          ret, out = run_command("mount -o loop #{dev} #{dir}")
        else
          raise Exception.new('Invalid device type')
        end
        return dir if ret == 0
      rescue Exception => e
        Domraider.log.info "Deleting tmp dir #{dir}"
        Dir.rmdir(dir) if File.directory?(dir)
      end
      nil
    end

    def self.vg_display
      names = []
      ret, out = run_command("vgdisplay")
      out.each_line do |l|
        names << $1.chomp.strip if l =~ /^\s+VG Name\s+(.*)$/
      end
      if ret != 0
        Domraider.log.error 'Error executing vg_display'
        raise Exception.new("ERROR: vg_display: #{out}")
      end
      names
    end

    def self.lv_display
      names = []
      ret, out = run_command("lvdisplay")
      out.each_line do |l|
        names << $1.chomp.strip.split('/').last if l =~ /^\s+LV Name\s+(.*)$/
      end
      if ret != 0 and ret =! 5
        Domraider.log.error 'Error executing lv_display'
        raise Exception.new("ERROR: lv_display: #{out}") 
      end
      names
    end

    def self.lv_format(vgname, lvname)
      if not File.exist? "/dev/#{vgname}/#{lvname}"
        Domraider.log.error "ERROR: LV /dev/#{vgname}/#{lvname} does not exist."
        raise Exception.new("ERROR: LV /dev/#{vgname}/#{lvname} does not exist.")
      end
      return mkfs("/dev/#{vgname}/#{lvname}")
    end

    def self.mkfs(path)
      ret, out = run_command("mkfs.ext3 -F #{path}")
      return true if ret == 0
      false
    end

    def self.mounted_fs?(device)
      `mount`.each_line do |l|
        return true if l =~ /^#{Regexp.escape(device)}/
      end
      false
    end

    #
    # returns an array: [PE, SIZE, UNITS]
    #
    def self.vg_size(vgname)
      ret, out = run_command("vgdisplay --units b #{vgname}")
      out.each_line do |l|
        if l.strip =~ /^\s*Free\s*PE\s*\/\s*Size\s*(.*)\s*\/\s*(.*)\s*(B|MB|GB|KB)$/
          return [$1.to_i, $2.to_f, $3]
        end
      end
      if ret != 0
        Domraider.log.error 'Error executing vg_size'
        raise Exception.new("ERROR: vg_size: #{out}")
      end
      return nil
    end

    #
    # lvsize in megabytes
    #
    def self.lv_create(vgname, lvname, lvsize)
      ret, out = run_command("lvcreate --name #{lvname} --size #{lvsize} #{vgname}")
      return true if ret == 0
      false
    end

    def self.lv_remove(lvpath)
      if not File.exist?(lvpath)
        raise Exception.new("Logical Volume path (#{lvpath}) not found.")
      end
      ret, out = run_command("lvremove -f #{lvpath}")
      return true if ret == 0
      false
    end

    def self.run_command(cmd)
      Domraider.log.debug cmd
      out = `#{cmd} 2>&1`
      Domraider.log.debug out
      Domraider.log.error "Error executing #{cmd}" if $? != 0
      return [$?, out]
    end

    #
    # size in MBytes
    # 
    # raises exception if path already exists
    #
    def self.create_sparse(path, size)
      raise Exception.new("Invalid sparse path. File #{path} already exists") if File.exist?(path)
      raise ArgumentError.new("Invalid sparse size") if not size.is_a? Integer
      ret, out = run_command("dd if=/dev/zero of=#{path} bs=1M count=0 seek=#{size}")
      raise Exception.new(out) if ret != 0
      nil
    end
    
    #
    # Path must be absolute
    # 
    def self.create_raw(path)
      if not File.exist?(path) or path !~ /^\/dev/
        raise Exception.new("Invalid path #{path}") 
      end
      raise Exception.new("Path must be absolute") if path !~ /^\//
      nil
    end

    #
    # Unpack the template tarball under target_dir
    # target_dir must exist
    # 
    # template must be a tar.bz2 file
    #
    def self.unpack_template(template_path, target_dir)
      if not File.exist?(template_path)
        raise Exception.new("Template file does not exist.")
      end
      if template_path !~ /.*\.tar\.bz2$/
        raise Exception.new("Invalid template archive, expecting .tar.bz2")
      end
      
      if not File.directory?(target_dir)
        raise Exception.new("Target directory does not exist")
      end

      bs = Sys::Filesystem::stat(target_dir).block_size
      free = Sys::Filesystem::stat(target_dir).blocks_available * bs
      if free < 1073741824
        raise Exception.new("Not enough space in target filesystem dir")
      end
      ret, out = run_command("tar -C #{target_dir} -xjpf #{template_path}")
      raise Exception.new(out) if ret != 0
      nil
    end
  end

  class BlockDevice

    def initialize(params={})
      @params = params
    end

    def path
      @params[:path]
    end

    #
    # Create a new BlockDevice from a Logical Volume
    #
    # params:
    #
    # :name - name of the LV
    # :size - LV size (in bytes)
    # :vg   - Volume Group to host the LV
    #
    # Raises Exception if lvcreate returns an error
    #
    def self.new_lv(vgroup, name, size, params={})
      raise ArgumentError.new("vgroup is invalid") if vgroup.nil?
      raise ArgumentError.new("name is invalid") if vgroup.nil?
      raise ArgumentError.new("size is invalid") if vgroup.nil?
      bpath = "/dev/#{vgroup}/#{name}"
      p = {
        :type => 'lv',
        :name => name,
        :size => size,
        :path => bpath,
        :be_dev => bpath,
        :fe_dev => params[:fe_dev] || 'sda1',
        :mode => params[:mode] || 'w',
        :vgroup => vgroup
      }.merge(params)
      bd = BlockDevice.new(p)
      return bd
    end

    def self.new_sparse(path, size, params={})
      p = {
        :type => 'sparse',
        :name => path,
        :path => path,
        :be_dev => path,
        :fe_dev => params[:fe_dev] || 'sda1',
        :mode => params[:mode] || 'w',
        :size => size.to_i
      }.merge(params)
      return BlockDevice.new(p)
    end

    def self.new_raw(path, params={})
      p = {
        :type => 'raw',
        :name => path,
        :path => path,
        :be_dev => path,
        :fe_dev => params[:fe_dev] || 'sda1',
        :mode => params[:mode] || 'w',
      }.merge(params)
      return BlockDevice.new(p)
    end

    def create(format_device=true)
      case @params[:type]
        when 'raw':
          Domraider::Util.create_raw(@params[:path])
        when 'sparse':
          Domraider::Util.create_sparse(@params[:path], @params[:size])
        when 'lv':
          raise Exception.new("Error creating logical volume") \
            if not Domraider::Util.lv_create(@params[:vgroup], @params[:name], @params[:size])
        else
          raise Exception.new("Invalid block device type")
      end
      format if format_device
    end

    def config_string
      if @params[:type] == 'sparse'
        return "'tap:aio:#{@params[:path]},#{@params[:fe_dev]},#{@params[:mode]}'"
      else
        return "'phy:#{@params[:path]},#{@params[:fe_dev]},#{@params[:mode]}'"
      end
    end
    
    def format
      ok = false
      if @params[:type] == 'lv'
        ok = Domraider::Util::lv_format(@params[:vgroup], @params[:name])
      elsif @params[:type] == 'sparse' or @params[:type] == 'raw'
        ok = Domraider::Util::mkfs(@params[:name])
      else
        raise Exception.new("Not implemented")
      end
      raise Exception.new("Error formatting the block device #{@params[:name]}") if not ok
    end
    
    def umount
      if @params[:type] == 'lv'
        `umount /dev/mapper/#{@params[:vgroup]}-#{@params[:name]}`
        raise Exception.new("Error umounting the block device") \
          if $? != 0
      elsif @params[:type] == 'sparse' or @params[:type] == 'raw'
        `umount #{@params[:name]}`
        raise Exception.new("Error umounting the block device") \
          if $? != 0
      else
        raise Exception.new("Not implemented")
      end
    end

    def mount
      mdir = nil
      if @params[:type] == 'lv'
        mdir = Domraider::Util::lv_mount(@params[:vgroup], @params[:name])
      elsif @params[:type] == 'sparse'
        mdir = Domraider::Util::mount_fs(@params[:name], 'sparse')
      elsif @params[:type] == 'raw'
        mdir = Domraider::Util::mount_fs(@params[:name])
      else
        raise Exception.new("Not implemented")
      end
      raise Exception.new("Error mounting the block device") if mdir.nil?
      return mdir
    end

    def delete
      if @params[:type] == 'lv'
        if not Domraider::Util::lv_remove("/dev/mapper/#{@params[:vgroup]}-#{@params[:name]}")
          raise Exception.new("Error deleting the logical volume.")
        end
      elsif @params[:type] == 'sparse'
        raise Exception.new("Loop device mounted, won't delete") \
          if Domraider::Util.mounted_fs?(@params[:name])
        File.delete(@params[:name])
      elsif @params[:type] == 'raw'
        raise Exception.new("Cannot delete a block device")
      else
        raise Exception.new("Not implemented")
      end
    end

  end

  class Vif

    def initialize(params = {})
      @bridge = params[:bridge]
      @mac = params[:mac] || Vif.random_mac
    end

    def self.random_mac
      mac = [ 0x00, 0x16, 0x3e,
              rand(0x7f),
              rand(0xff),
              rand(0xff) ]
      mac.map { |x| sprintf("%02x", x) }.join ":"
    end

    def config_string
      if not @bridge.nil?
        return "'bridge=#{@bridge},mac=#{@mac}'"
      else
        return "'mac=#{@mac}'"
      end
    end

  end

  class DomU

    attr_accessor :mem, :maxmem, :block_devices, :network_devices, :hostname
    attr_accessor :vcpus, :template, :swap_file_size

    def initialize
      @bootloader = '/usr/bin/pygrub'
      @mem = 512
      @maxmem = 1024
      @hostname = "domu_#{Time.now.to_i}"
      @block_devices = []
      @network_devices = []
      @on_reboot = 'restart'
      @on_crash = 'restart'
      @vcpus = 1
      @template = nil
      @swap_file_size = 0
    end

    def root_bd=(bd)
      @root_bd = bd
    end

    def config_string
      nd = []
      network_devices.each do |n|
        nd << n.config_string
      end
      bd = []
      block_devices.each do |b|
        bd << b.config_string
      end

      "bootloader = '#{@bootloader}'\n" + 
      "name = '#{@hostname}'\n" +
      "memory = '#{@mem}'\n" +
      "maxmem = '#{@maxmem}'\n" +
      "disk = [ #{ bd.join(',') } ]\n" +
      "vif = [ #{ nd.join(',') } ]\n" +
      "vcpus=#{@vcpus}\n" +
      "on_reboot = '#{@on_reboot}'\n" +
      "on_crash = '#{@on_crash}'\n"
    end
    
    def create(boot = false)
      raise Exception.new("Root block device not defined") if @root_bd.nil?
      raise Exception.new("Template file not defined") if @template.nil?
      @block_devices.each do |bd|
        bd.create
      end
      mdir = @root_bd.mount
      if @swap_file_size > 0
        `dd if=/dev/zero of=#{mdir}/swap bs=1M count=#{@swap_file_size}`
        if $? == 0
          `mkswap #{mdir}/swap`
        end
      end
      Domraider::Util::unpack_template(@template, mdir)
      @root_bd.umount
      cfg = "/tmp/domraider_cfg_#{Time.now.to_i}"
      save_config cfg
      if boot
        out = `xm create -c #{cfg}`
      end
    end

    def save_config(file)
      File.open(file, 'w') do |f|
        f.puts config_string
      end
    end

  end

end
