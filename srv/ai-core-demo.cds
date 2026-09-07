using { sap.capire.travels as our } from '../db/schema';

/**
 * Demonstrates using the `AICore` CAP service that @cap-js/ai provides,
 * directly — rather than implicitly through the Fiori recommendations UI.
 */
service AICoreDemo @(requires: 'authenticated-user') {

  /** Ask SAP-RPT-1 to predict Agency, Currency and Status for a description. */
  action predictTravel(description : String, contextRows : Integer) returns {
    predictionColumns : array of String;
    contextRowsSent   : Integer;
    predictions       : array of {
      column : String;
      value  : String;
      score  : Decimal;
    };
  };

  /** Query AI Core resource groups. Requires a real binding — see BRANCH.md. */
  function listResourceGroups() returns array of { id : String; status : String; };
}
