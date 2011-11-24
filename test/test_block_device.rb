require 'lib/domraider.rb'
require 'test/unit'

class TestBlockDevice < Test::Unit::TestCase

  def setup
  end

  def teardown
  end

  #
  # Test Logical Volume Operation
  #
  def test_lv_ops
    lvname = "testlv_#{Time.now.to_i}"
    bd = nil

    #
    # Test creating the LV
    #
    # vgroup does not exist
    assert_raises Exception do
      bd = Domraider::BlockDevice.new_lv('lkjwf99ex', lvname, 1024)
      bd.create
    end
    # invalid lv size
    assert_raises Exception do
      bd = Domraider::BlockDevice.new_lv('localvg', lvname, 100000000024)
      bd.create
    end

    assert_nothing_raised do 
      bd = Domraider::BlockDevice.new_lv('localvg', lvname, 1024)
      bd.create
    end
    # device is formatted by default, check it
    if `blkid /dev/mapper/localvg-#{lvname}` !~ /TYPE="ext3"/
      assert false
    end
    
    assert(bd.config_string == "'phy:/dev/localvg/#{lvname},sda1,w'")
    assert( File.exist? "/dev/mapper/localvg-#{lvname}")

    # lv already exists
    assert_raises Exception do
      bd = Domraider::BlockDevice.new_lv('localvg', lvname, 1024)
      bd.create
    end


    #
    # Test formatting the LV
    #
    bd.format
    if `blkid /dev/mapper/localvg-#{lvname}` !~ /TYPE="ext3"/
      assert false
    end
    
    #
    # Test mouting the LV
    #
    mdir = bd.mount
    assert(`mount | grep #{mdir}` =~ /#{mdir}/)
    assert_raises Exception do
      bd.mount
    end
    
    #
    # Test umounting the LV
    #
    bd.umount
    assert(`mount | grep #{mdir}`.strip.chomp.empty?)
    Dir.rmdir mdir

    #
    # Test deleting the LV
    #
    bd.delete
    assert( !File.exist?("/dev/mapper/localvg-#{lvname}") )
  end
    
  def test_sparse_ops
    sparse_path = "/tmp/test_#{Time.now.to_i}.image"
    bd = nil

    assert_nothing_raised do 
      bd = Domraider::BlockDevice.new_sparse(sparse_path, 256)
      bd.create
    end
    # device is formatted by default, check it
    t = Domraider::Util::fs_type(bd.path)
    assert(t == 'ext3')

    assert(bd.config_string == "'tap:aio:#{sparse_path},sda1,w'")
    # Existing sparse path
    assert_raise Exception do 
      bd = Domraider::BlockDevice.new_sparse(sparse_path, 256)
      bd.create
    end

    assert_nothing_raised do
      bd.format
    end
    mdir = bd.mount

    t = Domraider::Util::fs_type(bd.path)
    assert(t == 'ext3')

    # Sparse still mounted
    assert_raise Exception do
      bd.delete
    end

    bd.umount
    Dir.rmdir mdir
    bd.delete
  end
  
  def test_raw_ops
    raw_path = "/dev/localvg/raw-test"
    bd = nil

    # Invalid block device
    assert_raise Exception do 
      bd = Domraider::BlockDevice.new_raw("/dev/localvg/raw-test-sdlfkj")
      bd.create
    end

    # Invalid path (does not exist)
    assert_raise Exception do 
      bd = Domraider::BlockDevice.new_raw('tmp/foobar')
      bd.create
    end
    
    assert_nothing_raised do 
      bd = Domraider::BlockDevice.new_raw(raw_path)
      bd.create
    end
    # device is formatted by default, check it
    if `blkid #{raw_path}` !~ /TYPE="ext3"/
      assert false
    end
    assert(bd.config_string == "'phy:#{raw_path},sda1,w'")

    bd.format
    mdir = bd.mount
    bd.umount
    Dir.rmdir mdir

    # we cannot delete a block device
    assert_raise Exception do
      bd.delete
    end
  end

end
