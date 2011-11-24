require 'rake'
$:.unshift(File.dirname(__FILE__) + "/lib")
require 'domraider'
require 'hoe'

Hoe.new('Domraider', Domraider::VERSION) do |p|
  p.name = "domraider"
  p.author = "Sergio Rubio"
  p.description = %q{Domraider}
  p.email = 'sergio@rubio.name'
  p.summary = "Domraider"
  p.url = "http://www.cti.csic.es"
  #p.clean_globs = ['test/output/*.png']
  #p.changes = p.paragraphs_of('CHANGELOG', 0..1).join("\n\n")
  p.remote_rdoc_dir = '' # Release to root
  p.extra_deps << [ "sys-filesystem",">= 0.2" ]
  p.extra_deps << [ "highline",">= 1.0" ]
  p.extra_deps << [ "term-ansicolor",">= 0.0.4" ]
  p.extra_deps << [ "choice",">= 0.1" ]
  p.developer('Sergio Rubio', 'sergio@rubio.name')
end

task :clean do
  `rm pkg/*.gem`
end

task :devgem => [:clean, :gem] do
end

task :tit => [:devgem] do
  `scp pkg/*.gem root@xen-x.testing.cti.csic.es:`
  `ssh root@xen-x.testing.cti.csic.es gem install /root/domraider-#{V}.gem`
  `ssh root@xen-x.testing.cti.csic.es rm -f domraider-#{V}.gem`
end

task :publish_gem do
  `scp pkg/*.gem root@slmirror.csic.es:/espejo/rubygems/gems/`
  `ssh slmirror gem generate_index -d /espejo/rubygems/`
end
