using { sap.capire.travels as our } from '../db/schema';

/** Generative helpers over travel data. */
service TravelAssistant @(requires: 'authenticated-user') {

  type Summary {
    travelID         : Integer;
    summary          : String;
    model            : String;
    mocked           : Boolean;
    promptTokens     : Integer;
    completionTokens : Integer;
  };

  /** A one-paragraph natural-language summary of one travel. */
  function summarize(travelID : Integer) returns Summary;
}
