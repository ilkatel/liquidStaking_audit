import HowItWorksCard from "../../TW_components/HowItWorksCard";

const HowItWorks = () => {
  return (
    <div id="howItworks" className="pt-5 px-4 mx-auto container">
      <h2> How it works </h2>
      <div className=" flex flex-row">
      <HowItWorksCard text="Make a deposit in ASTR tokens"/>
      <HowItWorksCard text="Receive multiple rewards during the holding"/>
      <HowItWorksCard text="Use N-tokens to stay liquid and earn more"/>
      </div>
    </div>
  );
};

export default HowItWorks;
