task :default => :activate

desc 'symlink files into home directory and install plugins'
task :activate do
  working_dir = File.expand_path(File.dirname(__FILE__))
  home_dir = File.expand_path("~")
  dot_files = Dir.glob(File.join(working_dir,"*"))

  dot_files.each do |filename|
    next if filename =~ /Rakefile/ || filename =~ /README\.txt$/

    sym_link = File.join(home_dir,".#{File.basename(filename)}")

    rm_rf(sym_link) if File.symlink?(sym_link) || File.exist?(sym_link)
    ln_s filename, sym_link
  end
end
