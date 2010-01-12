#!/usr/bin/env ruby
 
#--
# Copyright &169;2001-2008 Integrallis Software, LLC. 
# All Rights Reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'log4r'
require 'log4r/yamlconfigurator'
require 'log4r/outputter/datefileoutputter'

class Log4r::Logger #:nodoc:
  # Rack CommonLogger middleware expects a << method
  def <<(text)
    info(text.delete!("\n"))
  end  
  
  def write(text)
    info(text.delete!("\n"))
  end
end

module Logging #:nodoc: all
  include Log4r
  
  def self.logger
    @@logger
  end
  
  def Logging.included(recipient)
    cfg = YamlConfigurator
    cfg['HOME'] = '.'
    begin
      cfg.load_yaml_file('logging.yaml') #TODO make this configurable
      logger = Logger['trellis']
    rescue
      logger = Logger.new 'trellis'
      formatter = PatternFormatter.new(:pattern => '%d %l: %m ', :date_pattern => '%y%m%d %H:%M:%S')
      logger.add Log4r::StdoutOutputter.new('stdout', :formatter=> formatter)
    end  
    logger.level = INFO
    recipient.instance_variable_set(:@logger, logger)  
    recipient.class.send(:define_method, :logger) { @logger }
  end
end
