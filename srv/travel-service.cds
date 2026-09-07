using { sap.capire.travels as our, sap } from '../db/schema';

/**
 * Manages travel bookings: which customer travels where, through which
 * agency, at what price, and in which approval state.
 */
service TravelService {

  entity Travels as projection on our.Travels;

  @readonly entity Bookings       as projection on our.Bookings;
  @readonly entity TravelAgencies as projection on our.TravelAgencies;
  @readonly entity Customers      as projection on our.Customers;
  @readonly entity Currencies     as projection on sap.common.Currencies;
  @readonly entity Countries      as projection on sap.common.Countries;
}
