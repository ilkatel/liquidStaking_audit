const FAQ = () => {
  return (
    <div id="faq" className="container flex flex-col-2 mx-auto px-4 space-x-12 mt-10">
      <div>
        <h2> FAQ </h2>
        <ul>
          <li> I1 </li>
          <li> I2 </li>
          <li> I3 </li>
          <li> I4 </li>
        </ul>
      </div>

      <div>
        <p className="border-2 rounded text-left">
          Proof of Transfer (PoX) is a novel blockchain consensus mechanism, the
          first to connect two separate blockchains (Bitcoin and Stacks). This
          unique relationship allows builders to leverage and extend Bitcoin’s
          powers without modifying Bitcoin itself. All Stacks transactions
          settle on Bitcoin, enabling Stacks transactions to benefit from
          Bitcoin’s security. PoX also has a sustainability benefit, as
          electricity already spent to secure Bitcoin is reused by Stacks,
          allowing builders to create more value from energy already spent. PoX
          is an extension to Proof-of-burn models where where miners compete by
          ‘burning’ (destroying) a proof-of-work cryptocurrency from an
          established blockchain as a proxy for computing resources. Unlike
          proof-of-burn, however, rather than burning the cryptocurrency, miners
          transfer the committed cryptocurrency to other participants in the
          network who are 'Stacking'.
        </p>
        <a> Read more </a>
        <a> Proof of Transfer whitepaper </a>
      </div>
    </div>
  );
};

export default FAQ;
