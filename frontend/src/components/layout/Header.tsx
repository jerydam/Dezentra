import { useState, useRef, useEffect, useCallback, useMemo } from "react";
import { HiOutlineBell } from "react-icons/hi";
import { BiLogIn, BiWallet } from "react-icons/bi";
import { FullLogo, Logo } from "../../pages";
import { Link, NavLink, useNavigate } from "react-router-dom";
import Container from "../common/Container";
import { useNotifications } from "../../utils/hooks/useNotifications";
import NotificationBadge from "../notifications/NotificationBadge";
import { useAuth } from "../../context/AuthContext";
import Button from "../common/Button";
import { useChat } from "../../utils/hooks/useChat";
import CurrencyToggle from "../common/CurrencyToggle";
import WalletConnectButton from "../web3/WalletConnectButton";
import { useWeb3 } from "../../context/Web3Context";
import { FiInfo } from "react-icons/fi";
import SefldVerification from "../common/SefldVerification";
import { useUserManagement } from "../../utils/hooks/useUser";

const NavList = [
  { title: "Home", path: "/" },
  { title: "Product", path: "/product" },
  { title: "Trade", path: "/trades" },
  { title: "Community", path: "/community" },
] as const;

const Header = () => {
  const { selectedUser, checkVerificationStatus } = useUserManagement();
  const navigate = useNavigate();
  const { user, isAuthenticated, logout } = useAuth();
  const { wallet, disconnectWallet } = useWeb3();
  const [showUserMenu, setShowUserMenu] = useState(false);
  // const [showWallet, setShowWallet] = useState(false);
  const [showVerifyModal, setShowVerifyModal] = useState(false);
  const userMenuRef = useRef<HTMLDivElement>(null);
  const { unreadCount, fetchUserUnreadCount } = useNotifications();
  const { loadConversations, totalUnreadMessages } = useChat();

  useEffect(() => {
    if (selectedUser?._id) {
      checkVerificationStatus(false);
    }
  }, [selectedUser?._id, checkVerificationStatus]);

  const fetchData = useCallback(
    async (silent = false) => {
      try {
        await Promise.allSettled([
          fetchUserUnreadCount(false, silent),
          loadConversations(false, silent),
        ]);
      } catch (error) {
        if (!silent) {
          console.error("Failed to fetch header data:", error);
        }
      }
    },
    [fetchUserUnreadCount, loadConversations]
  );

  useEffect(() => {
    let mounted = true;
    let intervalId: NodeJS.Timeout;

    const initializeFetch = async () => {
      if (!mounted) return;
      await fetchData();

      if (mounted) {
        intervalId = setInterval(() => fetchData(true), 30000);
      }
    };

    initializeFetch();

    return () => {
      mounted = false;
      if (intervalId) {
        clearInterval(intervalId);
      }
    };
  }, [fetchData]);

  // Click outside handler for user menu
  useEffect(() => {
    const handleClickOutside = (event: MouseEvent) => {
      if (
        userMenuRef.current &&
        !userMenuRef.current.contains(event.target as Node)
      ) {
        setShowUserMenu(false);
      }
    };

    if (showUserMenu) {
      document.addEventListener("mousedown", handleClickOutside);
      return () =>
        document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [showUserMenu]);

  const handleLogout = useCallback(async () => {
    try {
      setShowUserMenu(false);

      // Disconnect wallet if connected
      if (wallet.isConnected) {
        await disconnectWallet();
      }

      logout();
      navigate("/", { replace: true });
    } catch (error) {
      console.error("Error during logout:", error);
      logout();
      navigate("/", { replace: true });
    }
  }, [disconnectWallet, logout, navigate, wallet.isConnected]);

  const handleUserMenuToggle = useCallback(() => {
    setShowUserMenu((prev) => !prev);
  }, []);

  const handleProfileNavigation = useCallback(() => {
    setShowUserMenu(false);
    navigate("/account");
  }, [navigate]);

  return (
    <header className="w-full py-2 md:py-3 bg-[#212428] shadow-md sticky top-0 z-50">
      <Container className="flex items-center justify-between py-0">
        {/* Logo */}
        <Link
          to="/"
          className="flex items-center group transition-transform hover:scale-105"
          aria-label="Dezentra Home"
        >
          <div className="w-8 h-8 md:w-9 md:h-9 relative overflow-hidden">
            {/* <img
              src={FullLogo}
              className="w-full md:hidden transition-transform group-hover:scale-110 object-cover object-[25%_25%]"
              alt="dezentra logo"
              loading="eager"
            /> */}
            <img
              src={Logo}
              className="w-full transition-transform group-hover:scale-110 object-cover object-[25%_25%]"
              alt="dezentra logo"
              loading="eager"
            />
          </div>
          <span className="ml-2 text-white font-medium hidden md:inline transition-opacity group-hover:opacity-90">
            Dezentra
          </span>
        </Link>

        {/* Desktop Navigation */}
        <nav className="hidden md:flex items-center max-lg:gap-4 lg:gap-8 xl:gap-10">
          {NavList.map(({ title, path }) => (
            <NavLink
              key={path}
              to={path}
              className={({ isActive }) =>
                `font-semibold text-sm lg:text-md transition-all relative ${
                  isActive
                    ? "text-Red after:content-[''] after:absolute after:bottom-[-6px] after:left-0 after:w-full after:h-0.5 after:bg-Red after:rounded-full"
                    : "text-[#545456] hover:text-white"
                }`
              }
            >
              {title}
              {/* {title === "Chat" && totalUnreadMessages > 0 && (
                <span
                  className="absolute -top-2 -right-4 bg-Red text-white text-xs rounded-full h-5 w-5 flex items-center justify-center"
                  aria-label={`${totalUnreadMessages} unread messages`}
                >
                  {totalUnreadMessages > 9 ? "9+" : totalUnreadMessages}
                </span>
              )} */}
            </NavLink>
          ))}
        </nav>

        <div className="flex items-center gap-2 md:gap-3">
          <CurrencyToggle />

          {/* Wallet button */}
          <WalletConnectButton />

          {isAuthenticated ? (
            <>
              <button
                aria-label={`Notifications ${
                  unreadCount > 0 ? ", " + unreadCount + " unread" : ""
                }`}
                className="p-1.5 rounded-full hover:bg-[#292B30] transition-colors relative active:scale-95"
                onClick={() => navigate("/notifications")}
              >
                <HiOutlineBell className="text-xl text-white" />
                <NotificationBadge count={unreadCount} />
              </button>

              {/* User menu dropdown */}
              <div className="relative" ref={userMenuRef}>
                <button
                  onClick={handleUserMenuToggle}
                  className="focus:outline-none focus:ring-2 focus:ring-Red focus:ring-opacity-50 rounded-full active:scale-95"
                  aria-expanded={showUserMenu}
                  aria-haspopup="true"
                  aria-label="User menu"
                >
                  <img
                    src={
                      typeof user?.profileImage === "string"
                        ? user.profileImage
                        : `https://avatar.iran.liara.run/username?username=[${
                            user?.name?.split(" ")[0] || ""
                          }+${user?.name?.split(" ")[1] || ""}]`
                    }
                    alt=""
                    className="w-8 h-8 rounded-full ring-2 ring-[#292B30] hover:ring-Red transition-all"
                    loading="lazy"
                  />
                  {!user?.isVerified && (
                    <div className="absolute -top-1 -right-1">
                      <div className="relative group">
                        <div className="w-3 h-3 bg-yellow-500 rounded-full flex items-center justify-center">
                          <FiInfo className="text-black text-xs" />
                        </div>
                        <div className="absolute bottom-full right-0 mb-2 px-3 py-2 bg-gray-800 text-white text-xs rounded-lg opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-10 max-w-[200px] overflow-hidden">
                          <div className="font-semibold mb-1">
                            Account Verification Required
                          </div>
                          <div className="text-gray-300">
                            Complete passport verification to access trading,
                            withdrawals, and premium features
                          </div>
                          <div className="absolute top-full right-2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-gray-800"></div>
                        </div>
                      </div>
                    </div>
                  )}
                </button>

                {showUserMenu && (
                  <div
                    className="absolute right-0 mt-2 w-48 bg-[#212428] rounded-md shadow-lg py-1 z-50 border border-[#292B30]"
                    role="menu"
                    aria-orientation="vertical"
                  >
                    <button
                      onClick={handleProfileNavigation}
                      className="block w-full text-left px-4 py-2 text-sm text-white hover:bg-[#292B30] transition-colors"
                      role="menuitem"
                    >
                      My Account
                    </button>
                    {!user?.isVerified && (
                      <button
                        onClick={() => setShowVerifyModal(true)}
                        className="block w-full text-left px-4 py-2 text-sm text-white hover:bg-[#292B30] transition-colors"
                        role="menuitem"
                      >
                        <div className="flex items-center gap-2">
                          <span>Verify Account</span>
                          <div className="relative group">
                            <FiInfo className="text-yellow-500 text-sm cursor-help" />
                            <div className="absolute bottom-full left-1/2 transform -translate-x-1/2 mb-2 px-3 py-2 bg-gray-800 text-white text-xs rounded-lg opacity-0 group-hover:opacity-100 transition-opacity duration-200 pointer-events-none whitespace-nowrap z-10">
                              Verify your account to unlock all features
                              <div className="absolute top-full left-1/2 transform -translate-x-1/2 w-0 h-0 border-l-4 border-r-4 border-t-4 border-transparent border-t-gray-800"></div>
                            </div>
                          </div>
                        </div>
                      </button>
                    )}
                    <button
                      onClick={handleLogout}
                      className="block w-full text-left px-4 py-2 text-sm text-white hover:bg-[#292B30] transition-colors"
                      role="menuitem"
                    >
                      Sign Out
                    </button>
                  </div>
                )}
              </div>
            </>
          ) : (
            <Button
              title="Sign In"
              className="bg-Red text-white px-2 md:pl-2 md:pr-3 py-1.5 md:py-2 rounded-md hover:bg-opacity-90 transition-all active:scale-95"
              onClick={() => navigate("/login")}
              icon={<BiLogIn className="text-lg" />}
              iconPosition="start"
              aria-label="Sign in"
            />
          )}
        </div>
      </Container>
      <SefldVerification
        isOpen={showVerifyModal}
        onClose={() => setShowVerifyModal(false)}
      />
    </header>
  );
};

export default Header;
