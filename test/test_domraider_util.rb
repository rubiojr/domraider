require 'lib/domraider.rb'
require 'test/unit'

class TestDomraiderUtil < Test::Unit::TestCase
  include Domraider::Util

  TESTVG = 'localvg'

  def test_lv_display
    assert_nothing_raised do
      Domraider::Util::lv_display
    end
    assert(Domraider::Util::lv_display.is_a?(Array))
    assert(Domraider::Util::lv_display.size > 0)
  end

  def test_lv_create
    lvname = "testlv_#{Time.now.to_i}"
    assert_nothing_raised do
      Domraider::Util::lv_create(TESTVG, lvname, 1024)
    end
    assert(File.exist?("/dev/#{TESTVG}/#{lvname}"))
    Domraider::Util::lv_remove("/dev/#{TESTVG}/#{lvname}")
  end

  def test_lv_mount
    lvname = "testlv_#{Time.now.to_i}"
    Domraider::Util::lv_create(TESTVG, lvname, 1024)
    Domraider::Util::lv_format(TESTVG, lvname)
    mdir = ''

    assert_nothing_raised do
      mdir = Domraider::Util::lv_mount(TESTVG, lvname)
    end
    
    # if lv is already mounted, raise an exception
    assert_raise Exception do
      mdir = Domraider::Util::lv_mount(TESTVG, lvname)
    end

    assert(!mdir.strip.chomp.empty?)
    assert(!`mount | grep #{mdir}`.empty?)
    `umount #{mdir}`
    assert(Domraider::Util::lv_mount(TESTVG,'sdfosf').nil?)
    Domraider::Util::lv_remove("/dev/#{TESTVG}/#{lvname}")
    `rmdir #{mdir}`
  end

  def test_lv_format
    lvname = "testlv_#{Time.now.to_i}"
    Domraider::Util::lv_create(TESTVG, lvname, 1024)
    assert_nothing_raised do
      Domraider::Util::lv_format(TESTVG, lvname)
    end
    mdir = Domraider::Util::lv_mount(TESTVG, lvname)
    assert(!`mount|grep #{mdir}|grep ext3`.strip.chomp.empty?)
    assert_raise Exception do
      Domraider::Util::lv_format(TESTVG, 'lksj234lkjjuoSDWk')
    end
    `umount #{mdir}`
    Domraider::Util::lv_remove("/dev/#{TESTVG}/#{lvname}")
  end

  def test_vg_size
    assert(Domraider::Util::vg_size(TESTVG).is_a?(Array))
    assert(Domraider::Util::vg_size(TESTVG).size == 3)
    assert(Domraider::Util::vg_size(TESTVG)[2] == 'B')
  end
  
  def test_vg_display
    assert(Domraider::Util::vg_display.is_a?(Array))
    assert(Domraider::Util::vg_display.size > 0)
    Domraider::Util::vg_display.each do |vg|
      assert File.directory?("/dev/#{vg}")
    end
  end

  def test_lv_remove
    lvname = "testlv_#{Time.now.to_i}"
    Domraider::Util::lv_create(TESTVG, lvname, 1024)
    assert_nothing_raised do
      Domraider::Util::lv_remove("/dev/#{TESTVG}/#{lvname}")
    end
    assert(File.exist?("/dev/#{TESTVG}/#{lvname}") == false)
    assert_raise Exception do
      Domraider::Util::lv_remove('lv_invalid_2lkjjwou')
    end
  end

  def test_run_command
    assert_nothing_raised do
      ret, out = Domraider::Util::run_command('ls /')
      assert(ret == 0)
      assert(out.is_a?(String))
      ret, out = Domraider::Util::run_command('lskjdf')
      assert(ret != 0)
      assert(out.is_a?(String))
    end
  end

  def test_unpack_template
    template_path = '/var/lib/domraider/templates/sl5_x86_64/sl52-x86_64_vanilla_v027.tar.bz2'
    template_path2 = '/var/lib/domraider/templates/sl5_x86_64/sl52-x86_64_vanilla_v027.tar.gz'
    assert(false) if not File.exist?(template_path)
    tdir = '/mnt'
    tdir_invalid = '/tmp/unpack-test'

    # target dir does not exist
    assert_raise Exception do
      Domraider::Util::unpack_template(template_path, '/mntfosdoiu')
    end
    
    # Invalid template file
    assert_raise Exception do
      Domraider::Util::unpack_template(template_path2, tdir)
    end
    
    # Not enought free space
    assert_raise Exception do
      Domraider::Util::unpack_template(template_path, tdir_invalid)
    end

    assert_nothing_raised do
      Domraider::Util::unpack_template(template_path, tdir)
    end

    assert(File.exist?("#{tdir}/etc/redhat-release"))
  end

end
