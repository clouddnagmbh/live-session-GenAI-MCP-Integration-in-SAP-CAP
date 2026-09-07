using { TravelService } from '../srv/travel-service';

//
// Draft — this single annotation gates the whole AI recommendations feature.
//
annotate TravelService.Travels with @odata.draft.enabled;
annotate TravelService.Travels with @Common.SemanticKey: [ID];

// ID is assigned by the service (see srv/travel-service.js), so Fiori Elements
// must not prompt for it in the Create dialog.
annotate TravelService.Travels with { ID @Core.Computed };

//
// Value helps.
//
// Status and Currency need NO @Common.ValueList: their targets derive from
// sap.common.CodeList, which @sap/cds/common annotates with @cds.odata.valuelist.
// That inheritance is exactly why they become AI recommendation targets "for free"
// — and why it is easy to leak a code list to an LLM without noticing.
//
// Agency and Customer carry an explicit @Common.ValueList. The AI plugin looks for
// the *flattened* @Common.ValueList.CollectionPath, so CollectionPath must name an
// entity this service actually exposes.
//
annotate TravelService.Travels with {
  Status   @Common.ValueListWithFixedValues;

  Agency   @Common.ValueList: {
    CollectionPath: 'TravelAgencies',
    Parameters: [
      { $Type: 'Common.ValueListParameterInOut',       LocalDataProperty: Agency_ID, ValueListProperty: 'ID' },
      { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'Name' },
      { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'City' }
    ]
  };

  Customer @Common.ValueList: {
    CollectionPath: 'Customers',
    Parameters: [
      { $Type: 'Common.ValueListParameterInOut',       LocalDataProperty: Customer_ID, ValueListProperty: 'ID' },
      { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'LastName' },
      { $Type: 'Common.ValueListParameterDisplayOnly', ValueListProperty: 'FirstName' }
    ]
  };
};

// Readable text for the associations instead of raw IDs.
annotate TravelService.TravelAgencies with { Name @Common.Text: Name; };
annotate TravelService.Customers with {
  ID @Common.Text: LastName @Common.TextArrangement: #TextOnly;
};
