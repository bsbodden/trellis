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
  module CoreLibrary
    #
    #
    #
    class ObjectEditor < Trellis::Component
      is_stateful

      depends_on :form, :submit

      field :model, :persistent => true
      attr_reader :retrieve_block
      attr_reader :properties
      attr_accessor :submit_text
      attr_reader :submit_block

      def initialize
        @properties = []
      end

      # must be called before rendering
      def fields(*syms)
        syms.each do |sym|
          @properties << sym
        end
      end

      def on_submit(&block)
        # populate the object with values from the session
        if page.params
          properties.each do |property|
            value = page.params[property.to_sym]
            @model.instance_variable_set("@#{property}".to_sym, value)
          end
        end
        if block_given?
          @submit_block = block
        else
          @submit_block.call(@model)
        end
      end

      render do |tag|
        url_root = tag.globals.page.class.url_root
        # get the page object
        page = tag.globals.page
        # get the tag properties
        tid = tag.attr['tid']
        # get the instance of the component from the page
        editor = page.send("object_editor_#{tid}")
        # get the properties or columns
        properties = editor.properties
        # get the source from either the tag or the component instance itself
        source = tag.attr['model'] || editor.model
        submit_text = tag.attr['submit_text'] || editor.submit_text || "Submit"

        builder = Builder::XmlMarkup.new

        # the editor encloses a form
        form = tag.render("form", "tid" => "form_#{tid}", "method" => "post", "on_behalf" => "object_editor#{tid}") do
          builder.div(:class => "t-beaneditor") {
            properties.each { |property|
              field_name = property.to_s.humanize
              field_value = source.send(property)
              builder.div(:class => "t-beaneditor-row") {
                builder.label(field_name, :for => property, :id => "#{property}:label")
                builder.input(:id => property, :name => property, :type => "text", :value => field_value)
                builder.img(:alt => "[Error]", :class => "t-error-icon t-invisible", :id => "#{property}:icon", :src => "#{url_root}/images/field-error-marker.gif", :name => "#{property}:icon")
              }
            } if source
            builder.div(:class => "t-beaneditor-row") {
              builder << tag.render("submit", "tid" => "submit", "name" => "whats_the_name", "value" => submit_text)
            }
          }
        end
        form
      end

    end
  end
end
