CREATE OR REPLACE PACKAGE PKG_CLIENTE AS
    
    -- Códigos de erro padronizados
    c_erro_validacao        CONSTANT NUMBER := -20001;
    c_erro_duplicidade      CONSTANT NUMBER := -20002;
    c_erro_nao_encontrado   CONSTANT NUMBER := -20003;
    
    /**
     * Valida formato de email
     */
    FUNCTION FN_VALIDAR_EMAIL(p_email VARCHAR2) RETURN NUMBER;
    
    /**
     * Normaliza CEP removendo caracteres não numéricos
     **/
    FUNCTION FN_NORMALIZAR_CEP(p_cep VARCHAR2) RETURN VARCHAR2;
    
    /**
     * Insere novo cliente
     **/
    PROCEDURE PRC_INSERIR_CLIENTE(
        p_nome          IN VARCHAR2,
        p_email         IN VARCHAR2 DEFAULT NULL,
        p_cep           IN VARCHAR2 DEFAULT NULL,
        p_logradouro    IN VARCHAR2 DEFAULT NULL,
        p_bairro        IN VARCHAR2 DEFAULT NULL,
        p_cidade        IN VARCHAR2 DEFAULT NULL,
        p_uf            IN VARCHAR2 DEFAULT NULL,
        p_id            OUT NUMBER
    );
    
    /**
     * Atualiza dados de cliente existente
     **/
    PROCEDURE PRC_ATUALIZAR_CLIENTE(
        p_id            IN NUMBER,
        p_nome          IN VARCHAR2,
        p_email         IN VARCHAR2 DEFAULT NULL,
        p_cep           IN VARCHAR2 DEFAULT NULL,
        p_logradouro    IN VARCHAR2 DEFAULT NULL,
        p_bairro        IN VARCHAR2 DEFAULT NULL,
        p_cidade        IN VARCHAR2 DEFAULT NULL,
        p_uf            IN VARCHAR2 DEFAULT NULL
    );
    
    /**
     * Exclui cliente por ID
     **/
    PROCEDURE PRC_DELETAR_CLIENTE(p_id NUMBER);
    
    /**
     * Lista clientes com filtros opcionais
     **/
    PROCEDURE PRC_LISTAR_CLIENTES(
        p_nome  VARCHAR2,
        p_email VARCHAR2,
        p_rc    OUT SYS_REFCURSOR
    );
    /**
     * Lista clientes com filtros de id_cliente opcional
     **/
    PROCEDURE PRC_LISTAR_CLIENTES2(
        p_nome   VARCHAR2 DEFAULT NULL,
        p_email  VARCHAR2 DEFAULT NULL,
        p_id_cli NUMBER   DEFAULT NULL, 
        p_rc     OUT SYS_REFCURSOR
    );
    /**
     * Registra erro em TB_LOG_ERRO (autonomous transaction)
     **/
    PROCEDURE PRC_LOG_ERRO(
        p_origem    VARCHAR2,
        p_mensagem  VARCHAR2
    );
    
END PKG_CLIENTE;
/

CREATE OR REPLACE PACKAGE BODY PKG_CLIENTE AS
    
    FUNCTION FN_VALIDAR_EMAIL(p_email VARCHAR2) RETURN NUMBER IS
    BEGIN
        IF p_email IS NULL THEN
            RETURN 1;
        END IF;
        
        IF REGEXP_LIKE(p_email, '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$') THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    END FN_VALIDAR_EMAIL;
    
    FUNCTION FN_NORMALIZAR_CEP(p_cep VARCHAR2) RETURN VARCHAR2 IS
        v_cep VARCHAR2(8);
    BEGIN
        IF p_cep IS NULL THEN
            RETURN NULL;
        END IF;
        IF LENGTH(v_cep) BETWEEN 1 AND 7 THEN
          v_cep := LPAD(v_cep, 8, '0');
        END IF;
        
        v_cep := REGEXP_REPLACE(p_cep, '[^0-9]', '');
        
        --valida e rejeita CEPs com 8 dígitos todos iguais
        IF REGEXP_LIKE(v_cep, '^([0-9])\1{7}$') THEN
           RETURN NULL;
        END IF;
            
        RETURN v_cep;
    END FN_NORMALIZAR_CEP;
    
    PROCEDURE PRC_INSERIR_CLIENTE(
        p_nome          IN VARCHAR2,
        p_email         IN VARCHAR2 DEFAULT NULL,
        p_cep           IN VARCHAR2 DEFAULT NULL,
        p_logradouro    IN VARCHAR2 DEFAULT NULL,
        p_bairro        IN VARCHAR2 DEFAULT NULL,
        p_cidade        IN VARCHAR2 DEFAULT NULL,
        p_uf            IN VARCHAR2 DEFAULT NULL,
        p_id            OUT NUMBER
    ) IS
        v_cep VARCHAR2(8);
    BEGIN
        IF p_nome IS NULL OR TRIM(p_nome) IS NULL THEN
            RAISE_APPLICATION_ERROR(c_erro_validacao, 'Nome é obrigatório');
        END IF;
        
        IF FN_VALIDAR_EMAIL(p_email) = 0 THEN
            RAISE_APPLICATION_ERROR(c_erro_validacao, 'Email inválido');
        END IF;
        
        v_cep := FN_NORMALIZAR_CEP(p_cep);
        IF p_cep IS NOT NULL AND v_cep IS NULL THEN
            RAISE_APPLICATION_ERROR(c_erro_validacao, 'CEP deve ter 8 dígitos');
        END IF;
        
        IF p_uf IS NOT NULL AND p_uf NOT IN (
            'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG',
            'PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
        ) THEN
            RAISE_APPLICATION_ERROR(c_erro_validacao, 'UF inválida');
        END IF;
        
        BEGIN
            INSERT INTO TB_CLIENTE (
                NOME, EMAIL, CEP, LOGRADOURO, BAIRRO, CIDADE, UF
            ) VALUES (
                TRIM(p_nome), LOWER(TRIM(p_email)), v_cep, 
                TRIM(p_logradouro), TRIM(p_bairro), TRIM(p_cidade), p_uf
            ) RETURNING ID_CLIENTE INTO p_id;
            
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                RAISE_APPLICATION_ERROR(c_erro_duplicidade, 'Email já cadastrado');
        END;
    END PRC_INSERIR_CLIENTE;
    
    PROCEDURE PRC_ATUALIZAR_CLIENTE(
        p_id            IN NUMBER,
        p_nome          IN VARCHAR2,
        p_email         IN VARCHAR2 DEFAULT NULL,
        p_cep           IN VARCHAR2 DEFAULT NULL,
        p_logradouro    IN VARCHAR2 DEFAULT NULL,
        p_bairro        IN VARCHAR2 DEFAULT NULL,
        p_cidade        IN VARCHAR2 DEFAULT NULL,
        p_uf            IN VARCHAR2 DEFAULT NULL
    ) IS
        v_cep VARCHAR2(8);
    BEGIN
        IF p_nome IS NULL OR TRIM(p_nome) IS NULL THEN
            RAISE_APPLICATION_ERROR(c_erro_validacao, 'Nome é obrigatório');
        END IF;
        
        IF FN_VALIDAR_EMAIL(p_email) = 0 THEN
            RAISE_APPLICATION_ERROR(c_erro_validacao, 'Email inválido');
        END IF;
        
        v_cep := FN_NORMALIZAR_CEP(p_cep);
        
        IF p_cep IS NOT NULL AND v_cep IS NULL THEN
            RAISE_APPLICATION_ERROR(c_erro_validacao, 'CEP inconsistente!');
        END IF;
        
        IF p_uf IS NOT NULL AND p_uf NOT IN (
            'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG',
            'PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
        ) THEN
            RAISE_APPLICATION_ERROR(c_erro_validacao, 'UF inválida');
        END IF;
        
        UPDATE TB_CLIENTE
        SET NOME = TRIM(p_nome),
            EMAIL = LOWER(TRIM(p_email)),
            CEP = v_cep,
            LOGRADOURO = TRIM(p_logradouro),
            BAIRRO = TRIM(p_bairro),
            CIDADE = TRIM(p_cidade),
            UF = p_uf
        WHERE ID_CLIENTE = p_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(c_erro_nao_encontrado, 'Cliente não encontrado');
        END IF;
        
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(c_erro_duplicidade, 'Email já cadastrado');
    END PRC_ATUALIZAR_CLIENTE;
    
    PROCEDURE PRC_DELETAR_CLIENTE(p_id NUMBER) IS
    BEGIN
        DELETE FROM TB_CLIENTE WHERE ID_CLIENTE = p_id;
        
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(c_erro_nao_encontrado, 'Cliente não encontrado');
        END IF;
    END PRC_DELETAR_CLIENTE;
    
    PROCEDURE PRC_LISTAR_CLIENTES(
        p_nome  VARCHAR2,
        p_email VARCHAR2,
        p_rc    OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_rc FOR
        SELECT ID_CLIENTE, NOME, EMAIL, CEP, LOGRADOURO, BAIRRO, CIDADE, UF, ATIVO
        FROM TB_CLIENTE
        WHERE (p_nome IS NULL OR UPPER(NOME) LIKE '%' || UPPER(p_nome) || '%')
          AND (p_email IS NULL OR UPPER(EMAIL) LIKE '%' || UPPER(p_email) || '%')
        ORDER BY NOME, ID_CLIENTE;
    END PRC_LISTAR_CLIENTES;
    
    PROCEDURE PRC_LISTAR_CLIENTES2(
        p_nome   VARCHAR2 DEFAULT NULL,
        p_email  VARCHAR2 DEFAULT NULL,
        p_id_cli NUMBER   DEFAULT NULL, 
        p_rc     OUT SYS_REFCURSOR
    ) IS
    BEGIN
        OPEN p_rc FOR
        SELECT ID_CLIENTE, NOME, EMAIL, CEP, LOGRADOURO, BAIRRO, CIDADE, UF, ATIVO, DT_CRIACAO, DT_ATUALIZACAO
        FROM TB_CLIENTE
        WHERE (p_nome IS NULL OR UPPER(NOME) LIKE '%' || UPPER(p_nome) || '%')
          AND (p_email IS NULL OR UPPER(EMAIL) LIKE '%' || UPPER(p_email) || '%')
          AND (p_id_cli IS NULL OR ID_CLIENTE = p_id_cli)
        ORDER BY NOME, ID_CLIENTE;
    END PRC_LISTAR_CLIENTES2;
    
	PROCEDURE PRC_LOG_ERRO(
		p_origem    VARCHAR2,
		p_mensagem  VARCHAR2
	) IS
		PRAGMA AUTONOMOUS_TRANSACTION;
	BEGIN
		INSERT INTO TB_LOG_ERRO (DT_EVENTO, USUARIO, ORIGEM, MENSAGEM)
        VALUES (SYSTIMESTAMP, USER, p_origem, p_mensagem);
		COMMIT;
	END PRC_LOG_ERRO;

END PKG_CLIENTE;
/



