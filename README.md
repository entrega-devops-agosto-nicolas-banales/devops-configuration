# Documento Obligatorio ORT - Devops Agosto 2024 - Nicolás Bañales



## 1. Introducción

Este proyecto busca implementar una solución DevOps integral para una empresa del sector retail que desea modernizar la manera en que desarrolla, prueba y despliega software. El objetivo principal es optimizar el **time-to-market** y mejorar la calidad del software mediante la adopción de prácticas de integración y entrega continua (CI/CD), junto con la gestión de la infraestructura como código (IaC).



### Objetivo General

Alojar completamente en la nube pública una solución que utilice metodologías y herramientas DevOps, maximizando la escalabilidad, eficiencia y estabilidad de las aplicaciones desplegadas.



### Objetivos Específicos

1. **Diseño de infraestructura en la nube:** Utilizar un enfoque de IaC para desplegar recursos de manera automatizada y eficiente.

2. **Implementación de CI/CD:** Configurar pipelines para los microservicios backend y el frontend, garantizando despliegues rápidos y confiables.

3. **Gestión de microservicios:** Contenerizar y orquestar los microservicios, asegurando su correcta comunicación y escalabilidad.

4. **Pruebas y análisis de calidad:** Automatizar pruebas funcionales y análisis de código estático para asegurar la calidad de los servicios.

   

## 2. Arquitectura de la Solución

#### 

### Diagrama de flujo CI/CD

![CI_CD Diagram ](diagrams/ci-cd-diagram.jpg)

### Descripción del Flujo 

1. **Repositorio GitHub**:

   - El proceso se inicia con un **trigger** configurado en GitHub Actions, que se activa ante un evento de **push** o **merge** en las ramas monitoreadas, en mi caso main.

2. **Build and Test**:

   - En esta etapa se utiliza **Maven** para compilar el código fuente de los microservicios y generar el artefacto JAR correspondiente.
   - También se realizan los test definidos en el código para validar el funcionamiento del antes de continuar.

3. **Análisis de Código Estático (SonarCloud)**:

   - Se lleva a cabo un análisis de calidad del código con **SonarCloud**, identificando posibles vulnerabilidades, errores o malas prácticas.

4. **Docker Build and Push**:

   - Se construye una imagen Docker del microservicio utilizando el artefacto JAR generado en la etapa anterior.
   - La imagen es subida a un repositorio centralizado en **DockerHub**, etiquetada con la versión correspondiente.

5. **Despliegue en AWS ECS**:

   - La imagen Docker se despliega en un cluster configurado en **Amazon ECS**, asegurando que el servicio esté disponible para su uso en los entornos definidos.

6. **Despliegue en AWS ECS**:

   - Utilizando **Newman**, se ejecutan pruebas funcionales automatizadas para validar la correcta interacción de las APIs

     

## 3. Herramientas y Tecnologías Utilizadas



El proyecto hace uso de una combinación de herramientas modernas para garantizar la calidad del código, la eficiencia en el desarrollo y despliegue, y la estabilidad de la infraestructura. Estas herramientas fueron seleccionadas para cumplir con los requisitos del caso de estudio.

------

#### **Infraestructura como Código (IaC)**

- **Terraform** : Se utilizó para diseñar y desplegar la infraestructura en AWS. Los recursos definidos incluyen:
  - VPC, subredes, y grupos de seguridad.
  - Cluster ECS para contenerización.
  - Load Balancers para distribuir tráfico.
  - Buckets S3 para alojar la aplicación frontend y los logs del servicio serverless.

#### **Orquestación y Contenerización**

- **Docker**: Cada microservicio backend se empaquetó en una imagen Docker que se despliega en el cluster ECS.
- **AWS ECS (Elastic Container Service)**: Orquestador utilizado para manejar las tareas de los microservicios backend.

#### **Entrega e Integración Continua (CI/CD)**

- **GitHub Actions**: Incluye las siguientes etapas:
  - **Code Validation**: Análisis de código estático con **SonarCloud**.
  - **Build**: Compilación del código con **Maven**.
  - **Tests**: Pruebas funcionales con **Newman**.
  - **Deploy**: Despliegue en AWS ECS utilizando imágenes Docker.

#### **Análisis de Código**

- **SonarCloud**: Realiza análisis de código estático para identificar errores, vulnerabilidades y code smells. Los resultados se notifican como parte del flujo CI/CD.

#### **Gestión de Contenedores**

- **Docker Hub**: Almacena y distribuye las imágenes de contenedores etiquetadas con las versiones más recientes.

#### **Monitoreo y Automatización Serverless**

- **AWS Lambda**: Se implementó una función serverless para monitorear los servicios backend y generar logs.
- **CloudWatch**: Configurado para ejecutar la Lambda periódicamente (cada 5 minutos) mediante reglas de eventos.

#### **Frontend**

- **AWS S3**: La aplicación frontend está alojada como un sitio web estático utilizando un bucket S3 configurado para acceso público.

#### 

## 4. Demostración de Componentes y Procesos



#### **Análisis de Código Estático**

- **Descripción:** Se utiliza **SonarCloud** para realizar un análisis exhaustivo del código fuente.

- **Evidencia:**

  - Captura del dashboard de análisis de los microservicios y la aplicación front-end.

  - Indicadores de calidad como cobertura de pruebas, deuda técnica, y errores críticos.

    

![image-20241208073936956](C:\Users\ninot\AppData\Roaming\Typora\typora-user-images\image-20241208073936956.png)

#### **Pipeline CI/CD**

**Descripción:** El pipeline definido en `backend-ci-cd.yml` automatiza los procesos de construcción, prueba y despliegue. Está compuesto por las siguientes etapas:



![image-20241208074204279](C:\Users\ninot\AppData\Roaming\Typora\typora-user-images\image-20241208074204279.png)

#### **Arquitectura de Infraestructura**

**Descripción:** La infraestructura está diseñada utilizando Terraform y alojada en AWS. Incluye componentes como:

- Clusters ECS para backend.
- Buckets S3 para frontend.
- Load Balancers para distribución de tráfico.

