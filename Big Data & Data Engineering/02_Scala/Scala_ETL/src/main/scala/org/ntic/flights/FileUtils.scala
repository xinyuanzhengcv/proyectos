package org.ntic.flights

import org.ntic.flights.data.{Flight, Row}

import java.io.{FileOutputStream, ObjectOutputStream}
import scala.util.Try
import scala.io.Source

object FileUtils {

  /**
   * This function is used to check if the line is valid or not
   *
   * @param s : String
   * @return Boolean: true if the line is invalid, false otherwise
   */
  def isInvalidLine(s: String): Boolean ={
    val line = s.trim
    if (line.isEmpty) {
      true
    } else {
      val tokens = line.split(FlightsLoaderConfig.delimiter, -1)
      tokens.length != FlightsLoaderConfig.headersLength ||
        tokens.exists(_.trim.isEmpty)
    }
  }


  /**
   * This function is used to read the file located in the path `filePath` and return a list of lines of the file
   *
   * @param filePath: String
   * @return List[String]
   */
  def getLinesFromFile(filePath: String): List[String] = {
    val source = Source.fromFile(filePath)
    try {
      source.getLines().toList
    } finally {
      source.close()
    }
  }

  /**
   * This function is used to load the rows from the file lines
   *
   * @param fileLines: Seq[String]
   * @return Seq[Try[Row]]
   */
  def loadFromFileLines(fileLines: Seq[String]): Seq[Try[Row]] = {
    val lines =
      if (FlightsLoaderConfig.hasHeaders) fileLines.drop(1)
      else fileLines

    lines.map { line =>
      val tokens = line.split(FlightsLoaderConfig.delimiter, -1).toSeq
      Row.fromStringList(tokens)
    }
  }

  def writeFile(flights: Seq[Flight], outputFilePath: String): Unit = {
    val file = new java.io.File(outputFilePath)
    val parent = file.getParentFile
    if (parent != null && !parent.exists()) {
      parent.mkdirs()
    }

    val out = new ObjectOutputStream(new FileOutputStream(file))
    try {
      out.writeObject(flights)
    } finally {
      out.close()
    }
  }
}