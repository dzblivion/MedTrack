-- MySQL dump 10.13  Distrib 8.0.44, for Win64 (x86_64)
--
-- Host: localhost    Database: medtrack
-- ------------------------------------------------------
-- Server version	8.0.44

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `dias_semana_frequencia`
--

DROP TABLE IF EXISTS `dias_semana_frequencia`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `dias_semana_frequencia` (
  `regra_frequencia_id` int unsigned NOT NULL,
  `dia_semana` tinyint unsigned NOT NULL,
  PRIMARY KEY (`regra_frequencia_id`,`dia_semana`),
  CONSTRAINT `fk_dias_regra` FOREIGN KEY (`regra_frequencia_id`) REFERENCES `regras_frequencia` (`id`) ON DELETE CASCADE,
  CONSTRAINT `chk_dia_semana` CHECK ((`dia_semana` between 1 and 7))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `dias_semana_frequencia`
--

LOCK TABLES `dias_semana_frequencia` WRITE;
/*!40000 ALTER TABLE `dias_semana_frequencia` DISABLE KEYS */;
/*!40000 ALTER TABLE `dias_semana_frequencia` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `doses`
--

DROP TABLE IF EXISTS `doses`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `doses` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tratamento_id` int unsigned NOT NULL,
  `agendada_para` datetime NOT NULL,
  `status` enum('pendente','tomada','nao_tomada') NOT NULL DEFAULT 'pendente',
  `registrada_em` datetime DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_doses_tratamento_data` (`tratamento_id`,`agendada_para`),
  CONSTRAINT `fk_doses_tratamento` FOREIGN KEY (`tratamento_id`) REFERENCES `tratamentos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `doses`
--

LOCK TABLES `doses` WRITE;
/*!40000 ALTER TABLE `doses` DISABLE KEYS */;
/*!40000 ALTER TABLE `doses` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `horarios_frequencia`
--

DROP TABLE IF EXISTS `horarios_frequencia`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `horarios_frequencia` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `regra_frequencia_id` int unsigned NOT NULL,
  `horario` time NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_regra_horario` (`regra_frequencia_id`,`horario`),
  CONSTRAINT `fk_horarios_regra` FOREIGN KEY (`regra_frequencia_id`) REFERENCES `regras_frequencia` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `horarios_frequencia`
--

LOCK TABLES `horarios_frequencia` WRITE;
/*!40000 ALTER TABLE `horarios_frequencia` DISABLE KEYS */;
/*!40000 ALTER TABLE `horarios_frequencia` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `profissionais`
--

DROP TABLE IF EXISTS `profissionais`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `profissionais` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `usuario_id` int unsigned NOT NULL,
  `profissao` varchar(100) NOT NULL,
  `registro` varchar(50) NOT NULL,
  `uf_registro` char(2) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_profissionais_usuario` (`usuario_id`),
  CONSTRAINT `fk_profissionais_usuario` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `profissionais`
--

LOCK TABLES `profissionais` WRITE;
/*!40000 ALTER TABLE `profissionais` DISABLE KEYS */;
/*!40000 ALTER TABLE `profissionais` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `regras_frequencia`
--

DROP TABLE IF EXISTS `regras_frequencia`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `regras_frequencia` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `tratamento_id` int unsigned NOT NULL,
  `tipo` enum('diario','semanal','intervalo_horas','intervalo_dias') NOT NULL,
  `intervalo_valor` int DEFAULT NULL,
  `ancora_em` datetime NOT NULL,
  `fuso_horario` varchar(100) NOT NULL DEFAULT 'America/Fortaleza',
  `ativo` tinyint(1) NOT NULL DEFAULT '1',
  `criado_em` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_regras_tratamento` (`tratamento_id`),
  CONSTRAINT `fk_regras_tratamento` FOREIGN KEY (`tratamento_id`) REFERENCES `tratamentos` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `regras_frequencia`
--

LOCK TABLES `regras_frequencia` WRITE;
/*!40000 ALTER TABLE `regras_frequencia` DISABLE KEYS */;
/*!40000 ALTER TABLE `regras_frequencia` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `tratamentos`
--

DROP TABLE IF EXISTS `tratamentos`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `tratamentos` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `usuario_id` int unsigned NOT NULL,
  `medicamento` varchar(255) NOT NULL,
  `dosagem_valor` decimal(10,2) DEFAULT NULL,
  `dosagem_unidade` varchar(30) DEFAULT NULL,
  `quantidade_por_dose` decimal(10,2) NOT NULL DEFAULT '1.00',
  `forma_consumo` varchar(50) DEFAULT NULL,
  `data_inicio` datetime NOT NULL,
  `duracao_dias` int DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'ativo',
  `criado_em` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `fk_tratamentos_usuario` (`usuario_id`),
  CONSTRAINT `fk_tratamentos_usuario` FOREIGN KEY (`usuario_id`) REFERENCES `usuarios` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `tratamentos`
--

LOCK TABLES `tratamentos` WRITE;
/*!40000 ALTER TABLE `tratamentos` DISABLE KEYS */;
/*!40000 ALTER TABLE `tratamentos` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `usuarios`
--

DROP TABLE IF EXISTS `usuarios`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `usuarios` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `nome` varchar(120) NOT NULL,
  `email` varchar(150) NOT NULL,
  `senha_hash` varchar(255) NOT NULL,
  `criado_em` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_usuarios_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `usuarios`
--

LOCK TABLES `usuarios` WRITE;
/*!40000 ALTER TABLE `usuarios` DISABLE KEYS */;
/*!40000 ALTER TABLE `usuarios` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-09-11 16:21:35
