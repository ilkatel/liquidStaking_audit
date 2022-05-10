import ButtonOrange from "../TW_components/ButtonOrange";

const Header = () => {
  return (
    <nav className="relative flex-row container mx-auto p-4">
      <div className="flex items-center justify-between">
        <a href="/">
          <img
            className="h-7 mt-2"
            src="/images/Algem_Logo_Designs-07 3.svg"
            alt="logotype"
          ></img>
        </a>
        <div className="hidden md:flex space-x-3 text-base font-inter text-white-1 text-opacity-80">
          <a className="hover:text-white-1" href="#howItworks">
            How it works
          </a>
          <a className="hover:text-white-1" href="#faq">
            FAQ
          </a>
          <a
            target="_blank"
            href="https://docs.algem.io/"
            className="hover:text-white-1"
          >
            Docs
          </a>
          <a
            target="_blank"
            href="https://medium.com/@algem"
            className="hover:text-white-1"
          >
            Blog
          </a>
        </div>
        <ButtonOrange> Launch App </ButtonOrange>
      </div>
    </nav>
  );
};

export default Header;
