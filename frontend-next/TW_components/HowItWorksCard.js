import Image from "next/image";

const HowItWorksCard = ({text, imgSrc="/../public/images/header-bg-test.png"}) => {
  return (
    <div className="border-2 m-4 p-6 rounded text-left">
        <Image src={imgSrc} width={20} height={20}/>
      {text}
    </div>
  );
};

export default HowItWorksCard;
