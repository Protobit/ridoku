
module AWS
  class OpsWorks
    def client
      self
    end

    def self.stack(stack = nil)
      case stack
      when Hash
        @stack = stack
      when String
        begin
          @stack = JSON.parse(IO.read(stack))
        rescue => e
          raise e, "Invalid JSON file provided to AWS::OpsWorks.stack"
        end
      end

      @stack
    end

    def describe_stacks
      self.class.stack
    end
  end

  class EC2
    def client
      self
    end
  end

  class IAM
    def client
      self
    end
  end
end