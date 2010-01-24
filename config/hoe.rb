require 'trellis/version'

AUTHOR = 'Brian Sam-Bodden' 
EMAIL = "bsbodden@integrallis.com"
DESCRIPTION = "A component based web framework"
GEM_NAME = 'trellis' 
RUBYFORGE_PROJECT = 'trellis'
HOMEPATH = "http://#{RUBYFORGE_PROJECT}.rubyforge.org"
DOWNLOAD_PATH = "http://rubyforge.org/projects/#{RUBYFORGE_PROJECT}"
EXTRA_DEPENDENCIES = [
  ['paginator', '>= 1.1.1'],
  ['rack', '>= 1.1.0'],
  ['radius', '>= 0.6.1'],
  ['builder', '>= 2.1.2'],
  ['nokogiri', '>= 1.4.1'],
  ['extensions', '>= 0.6.0'],
  ['haml', '>= 2.2.17'],
  ['markaby', '>= 0.5'],
  ['RedCloth', '>= 4.2.2'],
  ['bluecloth', '>= 2.0.5'],
  ['log4r', '>= 1.1.2'],
  ['facets', '>= 2.8.1'],
  ['directory_watcher', '>= 1.3.1'], 
  ['eventmachine', '>= 0.12.10'],
  ['rack-cache', '>= 0.5.2'],
  ['rack-contrib', '>= 0.9.2'],
  ['rack-test', '>= 0.5.3'],
  ['erubis', '>= 2.6.5'],
  ['rspec', '>= 1.2.9'],
  ['newgem', '>= 1.5.2'],
  ['advisable', '>= 1.0.0']
]    # An array of rubygem dependencies [name, version]

@config_file = "~/.rubyforge/user-config.yml"
@config = nil
RUBYFORGE_USERNAME = "bsbodden"
def rubyforge_username
  unless @config
    begin
      @config = YAML.load(File.read(File.expand_path(@config_file)))
    rescue
      puts <<-EOS
ERROR: No rubyforge config file found: #{@config_file}
Run 'rubyforge setup' to prepare your env for access to Rubyforge
 - See http://newgem.rubyforge.org/rubyforge.html for more details
      EOS
      exit
    end
  end
  RUBYFORGE_USERNAME.replace @config["username"]
end


REV = nil
VERS = Trellis::VERSION::STRING + (REV ? ".#{REV}" : "")
RDOC_OPTS = ['--quiet', '--title', 'trellis documentation',
    "--opname", "index.html",
    "--line-numbers",
    "--main", "README",
    "--inline-source"]

class Hoe
  def extra_deps
    @extra_deps.reject! { |x| Array(x).first == 'hoe' }
    @extra_deps
  end
end

# Generate all the Rake tasks
# Run 'rake -T' to see list of generated tasks (from gem root directory)
$hoe = Hoe.spec GEM_NAME do
  self.version = VERS
  self.developer(AUTHOR, EMAIL)
  self.description = DESCRIPTION
  self.summary = DESCRIPTION
  self.url = HOMEPATH
  self.rubyforge_name = RUBYFORGE_PROJECT if RUBYFORGE_PROJECT
  self.test_globs = ["test/**/test_*.rb"]
  self.clean_globs |= ['**/.*.sw?', '*.gem', '.config', '**/.DS_Store']  #An array of file patterns to delete on clean.

  # == Optional
  self.changes = paragraphs_of("History.txt", 0..1).join("\n\n")
  self.extra_deps = EXTRA_DEPENDENCIES
end

CHANGES = $hoe.paragraphs_of('History.txt', 0..1).join("\\n\\n")
PATH    = (RUBYFORGE_PROJECT == GEM_NAME) ? RUBYFORGE_PROJECT : "#{RUBYFORGE_PROJECT}/#{GEM_NAME}"
$hoe.remote_rdoc_dir = File.join(PATH.gsub(/^#{RUBYFORGE_PROJECT}\/?/,''), 'rdoc')
$hoe.rsync_args = '-av --delete --ignore-errors'
$hoe.spec.post_install_message = File.open(File.dirname(__FILE__) + "/../PostInstall.txt").read rescue ""