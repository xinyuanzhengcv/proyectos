package org.ntic.flights.data

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.must.Matchers
import org.scalatest.matchers.should.Matchers.convertToAnyShouldWrapper

class FlightTest extends AnyFlatSpec with Matchers {

  "A Flight" should "be correctly initialized from string" in {
    val flightStr = "7/1/2023 12:00:00 AM;10136;ABI;Abilene, TX;TX;11298;DFW;Dallas/Fort Worth, TX;TX;1443;45.00;1606;68.00"
    val expected = Flight(
      "7/1/2023 12:00:00 AM",
      Airport(10136, "ABI", "Abilene, TX", "TX"),
      Airport(11298, "DFW", "Dallas/Fort Worth, TX", "TX"),
      Time(14, 43),
      Time(16, 6),
      45.00,
      68.00
    )
    val result = Flight.fromString(flightStr)
    result shouldEqual expected
  }

  "A Flight" should "be correctly initialized from string with negative minutes" in {
    val flightStr = "7/1/2023 12:00:00 AM;10136;ABI;Abilene, TX;TX;11298;DFW;Dallas/Fort Worth, TX;TX;622;-8.00;722;-8.00"
    val expected = Flight(
      "7/1/2023 12:00:00 AM",
      Airport(10136, "ABI", "Abilene, TX", "TX"),
      Airport(11298, "DFW", "Dallas/Fort Worth, TX", "TX"),
      Time(6, 22),
      Time(7, 22),
      -8.00,
      -8.00
    )
    val result = Flight.fromString(flightStr)
    result shouldEqual expected
  }

  "A Flight" should "be delayed" in {
    val flightStr = "7/1/2023 12:00:00 AM;10136;ABI;Abilene, TX;TX;11298;DFW;Dallas/Fort Worth, TX;TX;1443;45.00;1606;68.00"
    val expected = Flight(
      "7/1/2023 12:00:00 AM",
      Airport(10136, "ABI", "Abilene, TX", "TX"),
      Airport(11298, "DFW", "Dallas/Fort Worth, TX", "TX"),
      Time(14, 43),
      Time(16, 6),
      45.00,
      68.00
    )
    val result = Flight.fromString(flightStr)
    result shouldEqual expected
    result.isDelayed shouldEqual true
    result.actualDepTime shouldEqual Time(15, 28)
    result.actualArrTime shouldEqual Time(17, 14)
  }

  "A Flight" should "not be delayed" in {
    val flightStr = "7/1/2023 12:00:00 AM;10136;ABI;Abilene, TX;TX;11298;DFW;Dallas/Fort Worth, TX;TX;622;0.00;722;0.00"
    val expected = Flight(
      "7/1/2023 12:00:00 AM",
      Airport(10136, "ABI", "Abilene, TX", "TX"),
      Airport(11298, "DFW", "Dallas/Fort Worth, TX", "TX"),
      Time(6, 22),
      Time(7, 22),
      0.00,
      0.00
    )
    val result = Flight.fromString(flightStr)
    result shouldEqual expected
    result.isDelayed shouldEqual false
    result.actualDepTime shouldEqual Time(6, 22)
    result.actualArrTime shouldEqual Time(7, 22)
  }

  "A Flight" should "be delayed with negative minutes" in {
    val flightStr = "7/1/2023 12:00:00 AM;10136;ABI;Abilene, TX;TX;11298;DFW;Dallas/Fort Worth, TX;TX;622;-8.00;722;-8.00"
    val expected = Flight(
      "7/1/2023 12:00:00 AM",
      Airport(10136, "ABI", "Abilene, TX", "TX"),
      Airport(11298, "DFW", "Dallas/Fort Worth, TX", "TX"),
      Time(6, 22),
      Time(7, 22),
      -8.00,
      -8.00
    )
    val result = Flight.fromString(flightStr)
    result shouldEqual expected
    result.isDelayed shouldEqual true
    result.actualDepTime shouldEqual Time(6, 14)
    result.actualArrTime shouldEqual Time(7, 14)
  }

  "A Flight" should "be correctly initialized from Row" in {
    val row = Row(
      "7/1/2023 12:00:00 AM",
      10136,
      "ABI",
      "Abilene, TX",
      "TX",
      11298,
      "DFW",
      "Dallas/Fort Worth, TX",
      "TX",
      "1443",
      "45.00".toDouble,
      "1606",
      "68.00".toDouble
    )
    val expected = Flight(
      "7/1/2023 12:00:00 AM",
      Airport(10136, "ABI", "Abilene, TX", "TX"),
      Airport(11298, "DFW", "Dallas/Fort Worth, TX", "TX"),
      Time(14, 43),
      Time(16, 6),
      45.00,
      68.00
    )
    val result = Flight.fromRow(row)
    result shouldEqual expected
  }

  "Two Flights" should "be compared by actual arrival time" in {
    val flight1 = Flight(
      "7/1/2023 12:00:00 AM",
      Airport(10136, "ABI", "Abilene, TX", "TX"),
      Airport(11298, "DFW", "Dallas/Fort Worth, TX", "TX"),
      Time(14, 43),
      Time(16, 6),
      45.00,
      68.00
    )
    val flight2 = Flight(
      "7/1/2023 12:00:00 AM",
      Airport(10136, "ABI", "Abilene, TX", "TX"),
      Airport(11298, "DFW", "Dallas/Fort Worth, TX", "TX"),
      Time(15, 0),
      Time(16, 0),
      0.00,
      0.00
    )
    flight1.compare(flight2) shouldEqual 74
    flight2.compare(flight1) shouldEqual -74
  }
}
