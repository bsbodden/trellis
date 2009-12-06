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

require 'trellis/trellis'
require 'paginator'

module Trellis
  module CoreComponents
    
    # Component that triggers an action on the server with a subsequent full 
    # page refresh
    #
    class ActionLink < Trellis::Component
      render do |tag|
        source = tag.attr['tid'] 
        context = tag.attr['context']
        path = (tag.globals.page.path.nil? || tag.globals.page.path.empty?) ? nil : tag.globals.page.path
        class_name = tag.globals.page.class.name
        target_page = tag.attr['page'] || path || class_name

        if context
          value = tag.locals.instance_eval(context) || tag.globals.instance_eval(context)
        end

        if source
          if context
            id = "#{source}_#{value}"
            href = DefaultRouter.to_uri(:page => target_page,
                                                 :event => 'select',
                                                 :source => source,
                                                 :value => value)
          else
            id = "#{source}"
            href = DefaultRouter.to_uri(:page => target_page,
                                                 :event => 'select',
                                                 :source => source)
          end
        else
          if context
            id = "action_link_#{value}"
            href = DefaultRouter.to_uri(:page => target_page,
                                                 :event => 'select',
                                                 :value => value)
          else
            id = "action_link"
            href = DefaultRouter.to_uri(:page => target_page,
                                                 :event => 'select')
          end
        end
        
        builder = Builder::XmlMarkup.new
        text = builder.a('${contents}', "href" => href, "id" => id)
        text.replace_ant_style_property('contents', tag.expand)
      end
    end      
     
    #
    #
    #
    class Loop < Trellis::Component
      render do |tag|
        value_name = tag.attr['value']
        value = "#{value_name}="
        # make value available by name to the page   
        source = tag.attr['source']
        start, finish = source.split('..')
        content = ''
        (start..finish).each do |n|
          tag.locals.send(value.to_sym, n) 
          content << tag.expand
        end
        content
      end 
    end      

    #
    #
    #
    class Each < Trellis::Component
      render do |tag|
        value_name = tag.attr['value']
        value = "#{value_name}="
        # make value available by name to the page   
        source = tag.attr['source']
        begin
          iterator = tag.locals.instance_eval(source) || tag.globals.instance_eval(source)
        rescue NoMethodError
          iterator = []
        end
        content = ''
        iterator.each do |n|
          tag.locals.send(value.to_sym, n) 
          content << tag.expand
        end if iterator
        content
      end 
    end      
      
    #
    #
    #
    class Value < Trellis::Component
      render do |tag|
        name = tag.attr['name']
        unless name.include?('.')
          value = tag.locals.send(name.to_sym) || tag.globals.send(name.to_sym)
        else
          value = tag.locals.instance_eval(name) || tag.globals.instance_eval(name)
        end
        value
      end
    end

    class Eval < Trellis::Component
      render do |tag|
        expression = tag.attr['expression']
        tag.locals.instance_eval(expression) || tag.globals.instance_eval(expression) if expression
      end
    end
      
    #
    # page link should take parameters for pages that have a custom route
    #
    class PageLink < Trellis::Component
      render do |tag|
        url_root = tag.globals.page.class.url_root
        page_name = tag.attr['tpage']
        id = tag.attr['tid'] || page_name
        href = DefaultRouter.to_uri(:url_root => url_root, :page => page_name)
        contents = tag.expand
        builder = Builder::XmlMarkup.new
        builder.a(contents, "href" => href, "id" => "page_link_#{id}")
      end
    end
      
    #
    #
    #
    class Img < Trellis::Component
      render do |tag|
        attrs = tag.attr.exclude_keys('src', 'alt')
        
        # resolve the ${} variables 
        attrs['src'] = Utils.expand_properties_in_tag(tag.attr['src'], tag)
        attrs['alt'] = Utils.expand_properties_in_tag(tag.attr['alt'], tag)
        
        builder = Builder::XmlMarkup.new
        builder.img(attrs)
      end
    end
      
    #
    #
    #
    class Remove < Trellis::Component
      render do |tag|
        # do nothing
      end
    end
    
    #
    #
    #
    class If < Trellis::Component
      render do |tag|
        # resolve the ${} variables
        test = Utils.expand_properties_in_tag(tag.attr['test'], tag)
        value = tag.locals.instance_eval(test) || tag.globals.instance_eval(test)
        result = !value ? false : value
        tag.expand if result
      end
    end
    
    #
    #
    #
    class Unless < Trellis::Component
      render do |tag|
        # resolve the ${} variables  
        test = Utils.expand_properties_in_tag(tag.attr['test'], tag)
        value = tag.locals.instance_eval(test) || tag.globals.instance_eval(test)
        result = !value ? false : value
        tag.expand unless result
      end
    end
    
    #
    #
    #
    class Button < Trellis::Component
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type')
        attrs['name'] = "#{tag.attr['tid']}"
        contents = tag.expand        
        builder = Builder::XmlMarkup.new
        builder.button(contents, attrs)          
      end
    end
      
    #
    #
    #
    class Form < Trellis::Component
      render do |tag|
        url_root = tag.globals.page.class.url_root
        form_name = tag.attr['tid']
        on_behalf = tag.attr['on_behalf']
        method = tag.attr['method'] || 'GET'
        tag.locals.form_name = form_name
        value = tag.attr['value']
        
        if value
          eval_value = tag.locals.instance_eval(value) || tag.globals.instance_eval(value)
        end
        
        path = (tag.globals.page.path.nil? || tag.globals.page.path.empty?) ? nil : tag.globals.page.path
        class_name = tag.globals.page.class.name
        target_page = path || class_name   
        
        href = Trellis::DefaultRouter.to_uri(:url_root => url_root,
                                             :page => target_page,
                                             :event => "submit",
                                             :source => "#{(on_behalf ? on_behalf : form_name)}",
                                             :value => eval_value)
                                             
        attrs = tag.attr.exclude_keys('tid', 'on_behalf', 'method')
        attrs["name"] = form_name
        attrs["action"] = href 
        attrs["method"] = method    
                                          
        builder = Builder::XmlMarkup.new
        builder.form(attrs) do |form|
          form << tag.expand
        end
      end
    end     
     
    #
    #
    #
    class Submit < Trellis::Component
      tag_name "submit"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        attrs['type'] = 'submit'        
        builder = Builder::XmlMarkup.new
        builder.input(attrs)
      end
    end      
      
    #
    #
    #
    class CheckBox < Trellis::Component
      tag_name "check_box"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        attrs['type'] = 'checkbox'        
        builder = Builder::XmlMarkup.new
        builder.input(attrs)
      end
    end
    
    #
    #
    #
    class TextField < Trellis::Component
      tag_name "text_field"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type', 'value')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        value = tag.attr['value']
        literal = tag.attr['literal'] =~ /^(y|yes|true)$/
        if value 
          if !literal
            resolved_value = ''
            unless value.include?('.')
              resolved_value = tag.locals.send(value.to_sym) || tag.globals.send(value.to_sym)
            else
              target_name, method = value.split('.')
              target = tag.locals.send(target_name.to_sym) || tag.globals.send(target_name.to_sym)
              resolved_value = target.send(method.to_sym) if target
            end 
            attrs['value'] = resolved_value if resolved_value
          else
            attrs['value'] = value
          end
        end
        
        attrs['type'] = 'text'        
        builder = Builder::XmlMarkup.new
        builder.input(attrs)       
      end
    end
    
    #
    #
    #
    class TextArea < Trellis::Component
      tag_name "text_area"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'keep_contents')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"  
        keep_contents = tag.attr['keep_contents']  
        if keep_contents        
          contents = keep_contents =~ /^(y|yes|true)$/ ? tag.expand : ''
        else
          contents = ''
        end
        builder = Builder::XmlMarkup.new
        builder.textarea(contents, attrs)
      end 
    end 
    
    #
    #
    #
    class Password < Trellis::Component
      tag_name "password"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        attrs['type'] = 'password'        
        builder = Builder::XmlMarkup.new
        builder.input(attrs)       
      end
    end
      
    #
    #
    #
    class Hidden < Trellis::Component
      tag_name "hidden"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'name', 'type', 'value')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        value = tag.attr['value']
        literal = tag.attr['literal'] =~ /^(y|yes|true)$/
        if value 
          if !literal
            resolved_value = ''
            unless value.include?('.')
              resolved_value = tag.globals.send(value.to_sym)
            else
              target_name, method = value.split('.')
              target = tag.globals.send(target_name.to_sym)
              resolved_value = target.send(method.to_sym)
            end 
            attrs['value'] = resolved_value
          else
            attrs['value'] = value
          end
        end
        
        attrs['type'] = 'hidden'        
        builder = Builder::XmlMarkup.new
        builder.input(attrs)        
      end
    end
      
    #
    #
    #
    class Select < Trellis::Component    
      tag_name "select"
      
      contained_in "form"
      
      render do |tag|
        attrs = tag.attr.exclude_keys('tid', 'select_if', 'selected_value', 'source')
        attrs['name'] = "#{tag.locals.form_name}_#{tag.attr['tid']}"
        expression = tag.attr['source'] # something we can iterate over
        selected = Utils.evaluate_tag_attribute('select_if', tag)
        selected_value = Utils.evaluate_tag_attribute('selected_value', tag)
        value_accessor = Utils.expand_properties_in_tag(tag.attr['value'], tag)
        
        builder = Builder::XmlMarkup.new
        builder.select(attrs) do 
          if expression.include? '..'
            start, finish = expression.split('..')
            (start..finish).each do |item|
               value = value_accessor ? item.instance_eval(value_accessor) : item
               unless item == selected
                 builder.option item, :value => value
               else  
                 builder.option item, selected => (selected_value.nil? ? 'yes' : selected_value), :value => value
               end
            end
          else
            source = Utils.evaluate_tag_attribute('source', tag)
            if source.respond_to? :each
              source.each do |item|
                value = value_accessor ? item.instance_eval(value_accessor) : item
                unless item == selected
                  builder.option item, :value => value
                else  
                  builder.option item, :selected => (selected_value.nil? ? 'yes' : selected_value), :value => value
                end
              end
            elsif source.respond_to? :each_pair
              source.each_pair do |name,value|
                unless value == selected
                  builder.option name, :value => value
                else  
                  builder.option name, :selected => (selected_value.nil? ? value : selected_value), :value => value
                end
              end
            end
          end    
        end         
      end
    end
    
    
    # Returns a label tag tailored for labelling an input field for a specified attribute (identified by +method+) on an object
    # assigned to the template (identified by +object+). The text of label will default to the attribute name unless you specify
    # it explicitly. Additional options on the label tag can be passed as a hash with +options+. These options will be tagged
    # onto the HTML as an HTML element attribute as in the example shown.
    #
    # ==== Examples
    #   label(:post, :title)
    #   #=> <label for="post_title">Title</label>
    #
    #   label(:post, :title, "A short title")
    #   #=> <label for="post_title">A short title</label>
    #
    #   label(:post, :title, "A short title", :class => "title_label")
    #   #=> <label for="post_title" class="title_label">A short title</label>
    class Label < Trellis::Component
      render do |tag|
        target = "#{tag.locals.form_name}_#{tag.attr['for']}"  
        contents = tag.expand
        builder = Builder::XmlMarkup.new
        builder.label(contents, :for => target)        
      end
    end
      
    # Creates a file upload field.  If you are using file uploads then you will also need 
    # to set the multipart option for the form tag:
    #
    #   <%= form_tag { :action => "post" }, { :multipart => true } %>
    #     <label for="file">File to Upload</label> <%= file_field_tag "file" %>
    #     <%= submit_tag %>
    #   <%= end_form_tag %>
    #
    # The specified URL will then be passed a File object containing the selected file, or if the field 
    # was left blank, a StringIO object.
    #
    # ==== Options
    # * Creates standard HTML attributes for the tag.
    # * <tt>:disabled</tt> - If set to true, the user will not be able to use this input.
    #
    # ==== Examples
    #   file_field_tag 'attachment'
    #   # => <input id="attachment" name="attachment" type="file" />
    #
    #   file_field_tag 'avatar', :class => 'profile-input'
    #   # => <input class="profile-input" id="avatar" name="avatar" type="file" />
    #
    #   file_field_tag 'picture', :disabled => true
    #   # => <input disabled="disabled" id="picture" name="picture" type="file" />
    #
    #   file_field_tag 'resume', :value => '~/resume.doc'
    #   # => <input id="resume" name="resume" type="file" value="~/resume.doc" />
    #
    #   file_field_tag 'user_pic', :accept => 'image/png,image/gif,image/jpeg'
    #   # => <input accept="image/png,image/gif,image/jpeg" id="user_pic" name="user_pic" type="file" /> 
    #
    #   file_field_tag 'file', :accept => 'text/html', :class => 'upload', :value => 'index.html'
    #   # => <input accept="text/html" class="upload" id="file" name="file" type="file" value="index.html" />
    class File < Trellis::Component
      
      render do |tag|
        
      end
    end
      
    # TODO: Need radio button group and a standalone radio button
    
    class Div < Trellis::Component
      render do |tag|
        attrs = tag.attr.exclude_keys('id', 'title')
        attrs['id'] = Utils.expand_properties_in_tag(tag.attr['id'], tag) if tag.attr['id']
        attrs['title'] = Utils.expand_properties_in_tag(tag.attr['title'], tag) if tag.attr['title']
        builder = Builder::XmlMarkup.new
        builder.div(attrs) { |div|
          div << tag.expand
        }
      end
    end
    
  end
end