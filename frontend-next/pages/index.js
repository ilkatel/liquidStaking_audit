import Layout from "../components/Layout";
import FAQ from "../components/main_screen/FAQ";
import Hero from "../components/main_screen/Hero";
import HowItWorks from "../components/main_screen/HowItWorks";
import WhatIsAlgem from "../components/main_screen/WhatIsAlgem";

const Index = () => {
  return (
    <Layout>
      <Hero/>
      <WhatIsAlgem className="m-10"/>
      <HowItWorks/>
      <FAQ/>
    </Layout>
  );
};

export default Index;
