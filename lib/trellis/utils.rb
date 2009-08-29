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

module Kernel
  def with( object, &block )
    object.instance_eval(&block); object
  end
end

class Object #:nodoc:
  def meta_def(m,&b) #:nodoc:
    metaclass.send(:define_method,m,&b)
  end
  
  def metaclass
    class<<self;self end
  end
  
  def call_if_provided(sym)
    send sym if respond_to? sym
  end
end  

class Class #:nodoc:
  def class_to_sym
    underscore_class_name.to_sym
  end
  
  def underscore_class_name
    name.to_s.gsub(/::/, '/').
      gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      downcase.split('/').last
  end
  
  def meta_attr_accessor(*syms)
    syms.flatten.each do |sym|
      metaclass.instance_eval { attr_accessor(sym) }
    end
  end
  
  def meta_attr_reader(*syms)
    syms.flatten.each do |sym|
      metaclass.instance_eval { attr_reader(sym) }
    end
  end
  
  def meta_attr_writer(*syms)
    syms.flatten.each do |sym|
      metaclass.instance_eval { attr_writer(sym) }
    end
  end  
  
  def attr_array(plural_array_name_sym, options={}) 
    create_accessor = options[:create_accessor].nil? ? true : options[:create_accessor]
    plural_array_name_sym = plural_array_name_sym.to_s #convert to string if it is a symbol
    instance_variable_set("@#{plural_array_name_sym}".to_sym, Array.new)
    meta_def(plural_array_name_sym) { instance_variable_get("@#{plural_array_name_sym}".to_sym) } if create_accessor
  end
end

class String #:nodoc:
  def blank?
    self !~ /\S/
  end
  
  def replace_ant_style_property(property, value)
    result = self.gsub(/\$\{#{property.to_s}\}/) do |match|
      value
    end
    result
  end 
  
  def replace_ant_style_properties(properties)
    text = self
    properties.each_pair do |key,value|
      text = text.replace_ant_style_property(key, value)
    end
    text
  end  
  
  def humanize
    gsub(/_id$/, "").gsub(/_/, " ").capitalize
  end  
end

class Array #:nodoc:
  def next_to_last
    self.last(2).first if self.size > 1
  end
end

class Hash #:nodoc:
  def keys_to_symbols
    self.each_pair do |key, value| 
      self["#{key}".to_sym] = value if key
    end
  end
  
  def each_pair_except(*exceptions)
    _each_pair_except(exceptions)
  end
  
  def exclude_keys(*exceptions)
    result = Hash.new
    self._each_pair_except(exceptions) do |key, value|
      result[key] = value
    end
    result
  end
  
  protected
  
  def _each_pair_except(exceptions)
    self.each_pair do |key, value|  
      unless exceptions.include?(key) then
        yield [key, value]
      end
    end
  end
end

class File 
  def self.find(dir, filename="*.*", subdirs=true) 
    Dir[ subdirs ? File.join(dir.split(/\\/), "**", filename) : File.join(dir.split(/\\/), filename)  ] 
  end 
  
  def self.find_first(dir, filename, subdirs=false)
    find(dir, filename, subdirs).first
  end
  
end 


# class Radius::TagBinding #:nodoc:
#   
# end

module Utils
    
  # TODO open the tag ==> TagContext?? class
  def self.expand_properties_in_tag(text, tag)
    # resolve the ${} variables
    result = text #TODO not tested!
    result = text.gsub(/\$\{.*?\}/) do |match|
      name = match.split(/\$\{|\}/)[1] 
      unless name.include?('.')
        tag.locals.send(name.to_sym) || tag.globals.send(name.to_sym)   
      else
        target_name, method = name.split('.')
        target = tag.locals.send(target_name.to_sym) || tag.globals.send(target_name.to_sym)
        target.send(method.to_sym) if target
      end        
    end if text
    result
  end
  
  # TODO open the tag ==> TagContext?? class
  def self.evaluate_tag_attribute(attribute_name, tag)
    result = nil
    source = tag.attr[attribute_name]
    if source
      source = expand_properties_in_tag(source, tag)  
      begin
        local = tag.locals.instance_eval(source)
      rescue
        # log that they try to get a value that doesn't exist/can't be reached
      end
      begin
        global = tag.globals.instance_eval(source)
      rescue
        # same as above
      end

      if local
        result = local
      elsif global
        result = global
      end
    end
    result
  end  
  
end

