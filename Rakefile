require "fileutils"
require "tmpdir"

S3_BUCKET_NAME  = "heroku-buildpack-ruby"
VENDOR_URL      = "https://s3.amazonaws.com/#{S3_BUCKET_NAME}"

def s3_tools_dir
  File.expand_path("../support/s3", __FILE__)
end

def s3_upload(tmpdir, name)
  sh("#{s3_tools_dir}/s3 put #{S3_BUCKET_NAME} #{name}.tgz #{tmpdir}/#{name}.tgz")
end

def vendor_plugin(git_url)
  name = File.basename(git_url, File.extname(git_url))
  Dir.mktmpdir("#{name}-") do |tmpdir|
    FileUtils.rm_rf("#{tmpdir}/*")

    Dir.chdir(tmpdir) do
      sh "git clone #{git_url} ."
      FileUtils.rm_rf("#{name}/.git")
      sh("tar czvf #{tmpdir}/#{name}.tgz *")
      s3_upload(tmpdir, name)
    end
  end
end

def in_gem_env(gem_home, &block)
  old_gem_home = ENV['GEM_HOME']
  old_gem_path = ENV['GEM_PATH']
  ENV['GEM_HOME'] = ENV['GEM_PATH'] = gem_home.to_s

  yield

  ENV['GEM_HOME'] = old_gem_home
  ENV['GEM_PATH'] = old_gem_path
end

def install_gem(gem, version)
  name = "#{gem}-#{version}"
  Dir.mktmpdir("#{gem}-#{version}") do |tmpdir|
    Dir.chdir(tmpdir) do |dir|
      FileUtils.rm_rf("#{tmpdir}/*")

      in_gem_env(tmpdir) do
        sh("gem install #{gem} --version #{version} --no-ri --no-rdoc --env-shebang")
        sh("tar czvf #{tmpdir}/#{name}.tgz *")
        s3_upload(tmpdir, name)
      end
    end
  end
end

def build_ruby_command(name, output, prefix, usr_dir, tmpdir)
  build_command = [
    # need to move libyaml/libffi to dirs we can see
    "mv usr /tmp",
    "./configure --disable-install-doc --prefix #{prefix}",
    "env CPATH=/tmp/#{usr_dir}/include:\\$CPATH CPPATH=/tmp/#{usr_dir}/include:\\$CPPATH LIBRARY_PATH=/tmp/#{usr_dir}/lib:\\$LIBRARY_PATH make",
    "make install"
  ]
  build_command << "mv #{prefix} /app/vendor/#{name}" if name != output
  build_command = build_command.join(" && ")

  sh "vulcan build -v -o #{output}.tgz --source #{name} --command=\"#{build_command}\""
  s3_upload(tmpdir, output)
end

desc "update plugins"
task "plugins:update" do
  vendor_plugin "http://github.com/ddollar/rails_log_stdout.git"
  vendor_plugin "http://github.com/pedro/rails3_serve_static_assets.git"
  vendor_plugin "http://github.com/hone/rails31_enable_runtime_asset_compilation.git"
end

desc "install vendored gem"
task "gem:install", :gem, :version do |t, args|
  gem     = args[:gem]
  version = args[:version]

  install_gem(gem, version)
end

desc "install libyaml"
task "libyaml:install", :version do |t, args|
  version = args[:version]
  name = "libyaml-#{version}"
  Dir.mktmpdir("libyaml-") do |tmpdir|
    Dir.chdir(tmpdir) do |dir|
      FileUtils.rm_rf("#{tmpdir}/*")

      sh "curl http://pyyaml.org/download/libyaml/yaml-#{version}.tar.gz -s -o - | tar vzxf -"

      build_command = [
        "env CFLAGS=-fPIC ./configure --enable-static --disable-shared --prefix=/app/vendor/yaml-#{version}",
        "make",
        "make install"
      ].join(" && ")

      sh "vulcan build -v -o #{name}.tgz --source yaml-#{version} --command=\"#{build_command}\""
      s3_upload(tmpdir, name)
    end
  end
end

desc "install node"
task "node:install", :version do |t, args|
  version = args[:version]
  name    = "node-#{version}"
  prefix  = "/app/vendor/node-v#{version}"
  Dir.mktmpdir("node-") do |tmpdir|
    Dir.chdir(tmpdir) do |dir|
      FileUtils.rm_rf("#{tmpdir}/*")

      sh "curl http://nodejs.org/dist/node-v#{version}.tar.gz -s -o - | tar vzxf -"

      build_command = [
        "./configure --prefix #{prefix}",
        "make install",
        "mv #{prefix}/bin/node #{prefix}/.",
        "rm -rf #{prefix}/include",
        "rm -rf #{prefix}/lib",
        "rm -rf #{prefix}/share",
        "rm -rf #{prefix}/bin"
      ].join(" && ")

      sh "vulcan build -v -o #{name}.tgz --source node-v#{version} --command=\"#{build_command}\""
      s3_upload(tmpdir, name)
    end
  end
end

desc "install ruby"
task "ruby:install", :version do |t, args|
  version = args[:version]
  name    = "ruby-#{version}"
  usr_dir = "usr"
  Dir.mktmpdir("ruby-") do |tmpdir|
    Dir.chdir(tmpdir) do |dir|
      FileUtils.rm_rf("#{tmpdir}/*")

      sh "curl http://ftp.ruby-lang.org/pub/ruby/1.9/#{name}.tar.gz -s -o - | tar vzxf -"
      FileUtils.mkdir_p("#{name}/#{usr_dir}")
      Dir.chdir("#{name}/#{usr_dir}") do
        sh "curl #{VENDOR_URL}/libyaml-0.1.4.tgz -s -o - | tar vzxf -"
        sh "curl #{VENDOR_URL}/libffi-3.0.10.tgz -s -o - | tar vzxf -"
      end

      # runtime ruby
      prefix  = "/app/vendor/#{name}"
      build_ruby_command(name, name, prefix, usr_dir, tmpdir)

      # build ruby
      output  = "ruby-build-#{version}"
      prefix  = "/tmp/#{name}"
      build_ruby_command(name, output, prefix, usr_dir, tmpdir)
    end
  end
end

desc "install rbx"
task "rbx:install", :version do |t, args|
  version = args[:version]
  name    = "rubinius-#{version}"
  output  = "rbx-#{version}"
  prefix  = "/app/vendor/#{output}"

  Dir.mktmpdir("rbx-") do |tmpdir|
    Dir.chdir(tmpdir) do |dir|
      FileUtils.rm_rf("#{tmpdir}/*")

      sh "curl http://asset.rubini.us/#{name}.tar.gz -s -o - | tar vzxf -"
      build_command = [
        "./configure --prefix #{prefix}",
        "rake install"
      ].join(" && ")

      sh "vulcan build -v -o #{output}.tgz --source #{name} --prefix #{prefix} --command=\"#{build_command}\""
      s3_upload(tmpdir, output)
    end
  end
end

desc "generate ruby versions manifest"
task "ruby:manifest" do
  require 'rexml/document'
  require 'yaml'

  document = REXML::Document.new(`curl https://#{S3_BUCKET_NAME}.s3.amazonaws.com`)
  rubies   = document.elements.to_a("//Contents/Key").map {|node| node.text }.select {|text| text.match(/^(ruby|rbx)-\d+\.\d+\.\d+(-p\d+)?/) }

  Dir.mktmpdir("ruby_versions-") do |tmpdir|
    name = 'ruby_versions.yml'
    File.open(name, 'w') {|file| file.puts(rubies.to_yaml) }
    sh("#{s3_tools_dir}/s3 put #{S3_BUCKET_NAME} #{name} #{name}")
  end
end

desc "install libffi"
task "libffi:install", :version do |t, args|
  version = args[:version]
  name    = "libffi-#{version}"
  prefix  = "/app/vendor/#{name}"
  Dir.mktmpdir("libffi-") do |tmpdir|
    Dir.chdir(tmpdir) do |dir|
      FileUtils.rm_rf("#{tmpdir}/*")

      sh "curl ftp://sourceware.org/pub/libffi/libffi-#{version}.tar.gz -s -o - | tar vzxf -"

      build_command = [
        "env CFLAGS=-fPIC ./configure --enable-static --disable-shared --prefix=#{prefix}",
        "make",
        "make install",
        "mv #{prefix}/lib/#{name}/include #{prefix}",
        "rm -rf #{prefix}/lib/#{name}"
      ].join(" && ")

      sh "vulcan build -v -o #{name}.tgz --source #{name} --command=\"#{build_command}\""
      s3_upload(tmpdir, name)
    end
  end
end
