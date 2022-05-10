import ButtonOrange from "../../TW_components/ButtonOrange";

function Hero() {
  return (
    <section>
      <div
        className="container flex flex-col-reverse md:flex-row
          items-center px-6 mx-auto mt-10 space-y-0 md:space-y-0"
      >
        <div className="flex flex-col mb-32 space-y-10 md:w-1/2">
          <div className="text-left md:text-5xl font-inter text-7xl max-w-xl pt-52 text-white-1">
            Liquid staking and extra gains for the ASTR holders
          </div>
          <div class="flex justify-start space-x-5">
            <ButtonOrange> Try Algem </ButtonOrange>
            <a className="pt-3 pb-3 px-6 text-black-2 bg-orange-1 rounded hover:bg-orange-2">
              Learn More
            </a>
          </div>
        </div>
      </div>
    </section>
  );
}

export default Hero;
