import ButtonOrange from "../../TW_components/ButtonOrange";

const WhatIsAlgem = () => {
  return (
    <div className="container flex mx-auto px-4 space-y-12">
      <div>
        <div className="px-5 pb-5 flex flex-col space-y-5 md:w-1/2 border-2 rounded text-left">
          <h2 className="text-3xl font-inter text-left text-white-1">
            What is Algem
          </h2>
          <p className="text-left">
            Algem is a chain-specific DeFi dApp on top of the Astar Network with
            liquid staking, earnings and liquidity as a service functions.{" "}
          </p>

          <p className="text-left">
            Algem incentivizes users to hold their tokens via the multi-level
            rewards system.
          </p>
          <div className="container flex  space-y-12">
            <ButtonOrange>Read more</ButtonOrange>
          </div>
        </div>

        <div className="px-5 pb-5 flex flex-col space-y-5 md:w-1/2 border-2 rounded">
          Github repository Getting Started Guide
        </div>
      </div>

      <div className="flex-col space-y-5">
        <div className="border-2 rounded text-left">
          <h3 className="text-2xl font-inter text-left text-white-1">
            Multi-level rewards system
          </h3>
          <p>
            Long-term holding is much more juicy when you get additional reward
            for your patience
          </p>
          <p> Read more </p>
        </div>

        <div className=" mt-2 px-5 pt-5 pb-5 flex-col space-y-5 md:w-1/2 border-2 rounded text-left">
          <h3 className="text-2xl font-inter text-left text-white-1">
            Long holding
          </h3>
          <p>
            Unlock the real potential of your high-quality assets in a
            stress-less manner.
          </p>
        </div>
      </div>
    </div>
  );
};

export default WhatIsAlgem;
