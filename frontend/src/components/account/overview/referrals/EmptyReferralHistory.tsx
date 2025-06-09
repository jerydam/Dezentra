import { motion } from "framer-motion";
import { FiUserPlus } from "react-icons/fi";

interface EmptyReferralHistoryProps {
  onInviteFriends: () => void;
}

const EmptyReferralHistory: React.FC<EmptyReferralHistoryProps> = ({
  onInviteFriends,
}) => {
  return (
    <motion.div
      className="flex flex-col items-center justify-center py-12 px-4 text-center"
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      transition={{ duration: 0.5 }}
    >
      <motion.div
        className="w-20 h-20 rounded-full bg-[#333] flex items-center justify-center mb-4"
        initial={{ scale: 0.8 }}
        animate={{ scale: 1 }}
        transition={{ type: "spring", stiffness: 300, damping: 15 }}
      >
        <FiUserPlus size={32} className="text-Red" />
      </motion.div>

      <h3 className="text-xl font-medium text-white mb-2">No referrals yet</h3>
      <p className="text-gray-400 mb-6 max-w-xs">
        Start inviting friends to earn points and see your referral history
        here.
      </p>

      <motion.button
        className="bg-Red text-white py-3 px-6 rounded-lg"
        whileHover={{ scale: 1.05 }}
        whileTap={{ scale: 0.95 }}
        onClick={onInviteFriends}
      >
        Invite Friends
      </motion.button>
    </motion.div>
  );
};

export default EmptyReferralHistory;
