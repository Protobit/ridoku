# encoding: utf-8

class String
  def present?
    length > 0
  end
end

class NilClass
  def present?
    false
  end
end