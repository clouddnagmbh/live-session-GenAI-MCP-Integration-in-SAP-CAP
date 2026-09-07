using { TravelService } from '../srv/travel-service';

//
// Minimal Fiori elements annotations so CAP's built-in preview
// (/$fiori-preview/TravelService/Travels) is presentable. No UI5 app needed.
//
annotate TravelService.Travels with @(
  UI: {
    HeaderInfo: {
      TypeName      : 'Travel',
      TypeNamePlural: 'Travels',
      Title         : { Value: Description },
      Description   : { Value: ID }
    },
    SelectionFields: [ Status_code, Agency_ID, Currency_code ],
    LineItem: [
      { Value: ID,          Label: 'Travel' },
      { Value: Description                  },
      { Value: Agency.Name, Label: 'Agency' },
      { Value: Customer.LastName, Label: 'Customer' },
      { Value: BeginDate                    },
      { Value: EndDate                      },
      { Value: TotalPrice                   },
      { Value: Status.name, Label: 'Status', Criticality: Status.criticality }
    ],
    Facets: [
      { $Type: 'UI.ReferenceFacet', ID: 'General',  Label: 'General',  Target: '@UI.FieldGroup#General'  },
      { $Type: 'UI.ReferenceFacet', ID: 'Pricing',  Label: 'Pricing',  Target: '@UI.FieldGroup#Pricing'  },
      { $Type: 'UI.ReferenceFacet', ID: 'Bookings', Label: 'Bookings', Target: 'Bookings/@UI.LineItem'   }
    ],
    FieldGroup #General: { Data: [
      { Value: Description }, { Value: Agency_ID }, { Value: Customer_ID },
      { Value: BeginDate },   { Value: EndDate },   { Value: Status_code }
    ]},
    FieldGroup #Pricing: { Data: [
      { Value: BookingFee }, { Value: TotalPrice }, { Value: Currency_code }
    ]}
  }
);

annotate TravelService.Bookings with @(
  UI.LineItem: [
    { Value: Pos,         Label: 'Pos' },
    { Value: FlightNo                  },
    { Value: BookingDate               },
    { Value: Price                     },
    { Value: Currency_code             }
  ]
);
