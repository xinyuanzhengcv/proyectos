package org.ntic.flights.data

import org.scalatest.flatspec.AnyFlatSpec
import org.scalatest.matchers.must.Matchers
import org.scalatest.matchers.should.Matchers.convertToAnyShouldWrapper

import scala.util.Try



class RowTest extends AnyFlatSpec with Matchers{

    "A Row" should "return a Try and be correctly initialized from string" in {
      val rowStr = "7/1/2023 12:00:00 AM;10136;ABI;Abilene, TX;TX;11298;DFW;Dallas/Fort Worth, TX;TX;1443;45.00;1606;68.00"
      val expected = Row(
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
        45.00,
        "1606",
        68.00
      )
      val tryExpected = Try(expected)

      val result = Row.fromStringList(rowStr.split(";").toSeq)
      result shouldEqual tryExpected
      result.get shouldEqual expected
    }


}
