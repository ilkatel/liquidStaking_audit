const ButtonOrange = (props) => {
  return (
    <button
      {...props}
      className="pt-3 pb-3 px-6 text-black-2 bg-orange-1 rounded hover:bg-orange-2"
    >
      {props.children}
    </button>
  );
};

export default ButtonOrange;
