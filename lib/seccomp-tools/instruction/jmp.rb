require 'seccomp-tools/const'
require 'seccomp-tools/instruction/base'

module SeccompTools
  module Instruction
    # Instruction jmp.
    class JMP < Base
      # Decompile instruction.
      def decompile
        return goto(k) if jop == :none
        # if jt == 0 && jf == 0 => no-op # should not happen
        # jt == 0 => if(!) goto jf
        # jf == 0 => if() goto jt;
        # otherwise => if () goto jt; else goto jf;
        return '/* no-op */' if jt.zero? && jf.zero?
        return goto(jt) if jt == jf
        return if_str + goto(jt) + ' else ' + goto(jf) unless jt.zero? || jf.zero?
        return if_str + goto(jt) if jf.zero?
        if_str(true) + goto(jf)
      end

      # @return [Array<(Integer, Context)>]
      def branch(context)
        return [[at(k), context]] if jop == :none
        return [[at(jt), context]] if jt == jf
        [[at(jt), context], [at(jf), context]]
      end

      private

      def jop
        case Const::BPF::JMP.invert[code & 0x70]
        when :ja then :none
        when :jgt then :>
        when :jge then :>=
        when :jeq then :==
        when :jset then :&
        else invalid('unknown jmp type')
        end
      end

      def src_str
        return 'X' if SRC.invert[code & 8] == :x
        # if A in all contexts are same
        a = contexts.map(&:a).uniq
        return k.to_s if a.size != 1
        a = a[0]
        return k.to_s unless a.instance_of?(Array) && a.first == :data
        case a.last
        when 0 then Util.colorize((Const::Syscall.const_get(arch.upcase.to_sym).invert[k] || k).to_s, t: :syscall)
        when 4 then Util.colorize(Const::Audit::ARCH.invert[k] || k.to_s(16), t: :arch)
        else '0x' + k.to_s(16)
        end
      end

      def goto(off)
        format('goto %04d', at(off))
      end

      def at(off)
        line + off + 1
      end

      def if_str(neg = false)
        return "if (A #{jop} #{src_str}) " unless neg
        return "if (!(A & #{src_str})) " if jop == :&
        op = case jop
             when :>= then :<
             when :> then :<=
             when :== then :!=
             end
        "if (A #{op} #{src_str}) "
      end
    end
  end
end