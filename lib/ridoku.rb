# encoding: utf-8

module Ridoku
  def self.register(name)
    (@commands ||= []) << name.to_s
  end

  def self.commands
    @commands
  end
end
