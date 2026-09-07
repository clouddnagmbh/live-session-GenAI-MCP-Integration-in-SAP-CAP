using { sap, managed, Currency } from '@sap/cds/common';

namespace sap.capire.travels;

type Price : Decimal(9,4);

/**
 * A travel booked by a customer through an agency.
 * Its status follows Open -> Accepted | Rejected.
 */
entity Travels : managed {
  key ID        : Integer                        @title: 'Travel ID';
      Description : String(1024)                 @title: 'Description';
      BeginDate : Date default $now              @title: 'Begin Date';
      EndDate   : Date default $now              @title: 'End Date';
      BookingFee: Price default 0                @title: 'Booking Fee';
      TotalPrice: Price @readonly                @title: 'Total Price';
      Currency  : Currency                       @title: 'Currency';
      Status    : Association to TravelStatus default 'O' @title: 'Status';
      Agency    : Association to TravelAgencies  @title: 'Agency';
      Customer  : Association to Customers       @title: 'Customer';
      Bookings  : Composition of many Bookings on Bookings.Travel = $self;
}

/** A single flight booking within a travel. */
entity Bookings {
  key Travel     : Association to Travels;
  key Pos        : Integer                       @title: 'Position';
      FlightNo   : String(6)                     @title: 'Flight No';
      BookingDate: Date default $now             @title: 'Booking Date';
      Price      : Price                         @title: 'Price';
      Currency   : Currency                      @title: 'Currency';
}

/** A travel agency that sells travels. */
entity TravelAgencies {
  key ID   : Integer            @title: 'Agency ID';
      Name : String(80)         @title: 'Name';
      City : String(60)         @title: 'City';
      Country : Association to sap.common.Countries @title: 'Country';
}

/** A customer who books travels. */
entity Customers {
  key ID        : Integer       @title: 'Customer ID';
      FirstName : String(40)    @title: 'First Name';
      LastName  : String(40)    @title: 'Last Name';
      Email     : String(120)   @title: 'Email';
}

/** Status code list for travels. Inherits @cds.odata.valuelist from sap.common.CodeList. */
entity TravelStatus : sap.common.CodeList {
  key code : String(1) enum {
    Open     = 'O';
    Accepted = 'A';
    Rejected = 'X';
  }
}
